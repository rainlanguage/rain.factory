//! # Deploy Crate
//!
//! Deploy crate is a collection of utilities to cross deploy a contract (specifically Rain Contracts)
//! to other supported chains.

use anyhow::Result;
use crate::{subgraph::get_transaction_hash, deploy::registry::{Fuji, RainNetworks}, cli::deploy::CrossDeploy};
use self::{registry::{RainNetworkOptions, Ethereum, Mumbai, Polygon}, transaction::get_transaction_data, dis::{DISpair, replace_dis_pair}}; 
use ethers::providers::{Provider, Middleware, Http} ; 
use ethers::{signers::LocalWallet, types::{Eip1559TransactionRequest, U64}, prelude::SignerMiddleware};
use std::str::FromStr;
pub mod registry; 
use anyhow::anyhow; 

pub mod transaction; 
pub mod dis; 

/// Builds and returns contract deployment data for the provided target network [DISpair].
/// Optional transaction hash as an argument can be provided, which is recommended for Non-Rain contracts.
/// Returns deployment data for any contract without a constructor argument. 
/// For contracts which have constructor arguments the integrity of the returned data cannot be ensured.  
/// Returned data can directly be submitted via a signer to the blockchain. 
/// 
/// # Example 
/// ```rust
///  use rain_cli_factory::deploy::dis::DISpair;
///  use rain_cli_factory::deploy::get_deploy_data; 
///  use rain_cli_factory::deploy::registry::RainNetworks; 
///  use rain_cli_factory::deploy::registry::Mumbai; 
///  use std::env ;
///  
/// async fn get_contract_data(){
/// 
///    // Origin network
///    let mumbai_network = Mumbai::new(env::var("MUMBAI_RPC_URL").unwrap(), env::var("POLYGONSCAN_API_KEY").unwrap()) ; 
///    let from_network: RainNetworks = RainNetworks::Mumbai(mumbai_network); 
/// 
///    // Origin network contract address
///    let contract_address = String::from("0x3cc6c6e888b4ad891eea635041a269c4ba1c4a63") ;  
/// 
///    // Optional transaction hash can also be provided
///    let tx_hash = Some(String::from("0xc215bf3dc7440687ca20e028158e58640eeaec72d6fe6738f6d07843835c2cde")) ; 
///    
///    // Origin network DISpair
///    let from_dis = DISpair {
///        interpreter : Some(String::from("0x5f02c2f831d3e0d430aa58c973b8b751f3d81b38")),
///        store : Some(String::from("0xa5d9c16ddfd05d398fd0f302edd9e9e16d328796")),
///        deployer : Some(String::from("0xd3870063bcf25d5110ab9df9672a0d5c79c8b2d5")),
///   } ; 
///    
///    // Target Network DISpair
///    let to_dis = DISpair {
///        interpreter : Some(String::from("0xfd1da7eee4a9391f6fcabb28617f41894ba84cdc")),
///        store : Some(String::from("0x9b8571bd2742ec628211111de3aa940f5984e82b")),
///        deployer : Some(String::from("0x3d7d894afc7dbfd45bf50867c9b051da8eee85e9")),
///    } ;   
///     
///    // Get contract deployment data. 
///    let contract_deployment_data = get_deploy_data(
///        from_network,
///        contract_address,
///        from_dis,
///        to_dis,
///        tx_hash
///    ).await.unwrap() ;
/// 
/// }
pub async fn get_deploy_data(
    from_network : RainNetworks ,
    contract_address : String ,
    from_dis : DISpair , 
    to_dis : DISpair ,
    tx_hash : Option<String>
) -> Result<String> {  

    let tx_hash = match tx_hash {
        Some(hash) => hash ,
        None => {
            get_transaction_hash(from_network.clone(), contract_address).await?
        }
     } ;  

     let tx_data = get_transaction_data(from_network, tx_hash).await? ;  
     // Replace DIS instances 
     let tx_data = replace_dis_pair(tx_data,from_dis,to_dis).unwrap() ;  

     Ok(tx_data)
      
}  

/// Builds contract deployment data from [CrossDeploy] when called via the cli. 
/// Submits the transaction to the target network with the provided signer. 
/// Also check if the necessary environment varibales i.e rpcs and api keys are read and set to corresponding args.
pub async fn deploy_contract(consumer : CrossDeploy)  -> Result<()> {   

    let from_network: RainNetworks = match consumer.origin_network  {
        RainNetworkOptions::Ethereum => {
            if consumer.mumbai_rpc_url.is_none(){
                return Err(anyhow!("\n ❌Please provide --ethereum-rpc-url argument.")) ;
            }
            if consumer.polygonscan_api_key.is_none(){
                return Err(anyhow!("\n ❌Please provide --etherscan-api-key argument.")) ;
            }
            RainNetworks::Ethereum(Ethereum::new(consumer.ethereum_rpc_url.clone().unwrap(), consumer.etherscan_api_key.unwrap()))
        } ,
        RainNetworkOptions::Polygon => {
            if consumer.mumbai_rpc_url.is_none(){
                return Err(anyhow!("\n ❌Please provide --polygon-rpc-url argument.")) ;
            }
            if consumer.polygonscan_api_key.is_none(){
                return Err(anyhow!("\n ❌Please provide --polygonscan-api-key argument.")) ;
            }
            RainNetworks::Polygon(Polygon::new(consumer.polygon_rpc_url.clone().unwrap(), consumer.polygonscan_api_key.unwrap()))
        },
        RainNetworkOptions::Mumbai => { 
            if consumer.mumbai_rpc_url.is_none(){
                return Err(anyhow!("\n ❌Please provide --mumbai-rpc-url argument.")) ;
            }
            if consumer.polygonscan_api_key.is_none(){
                return Err(anyhow!("\n ❌Please provide --polygonscan-api-key argument.")) ;
            }  
            RainNetworks::Mumbai(Mumbai::new(consumer.mumbai_rpc_url.clone().unwrap(), consumer.polygonscan_api_key.unwrap()))
        },
        RainNetworkOptions::Fuji => {
            if consumer.mumbai_rpc_url.is_none(){
                return Err(anyhow!("\n ❌Please provide --fuji-rpc-url argument.")) ;
            }
            if consumer.polygonscan_api_key.is_none(){
                return Err(anyhow!("\n ❌Please provide --snowtrace-api-key argument.")) ;
            }
            RainNetworks::Fuji(Fuji::new(consumer.fuji_rpc_url.clone().unwrap(), consumer.snowtrace_api_key.unwrap()))
        }
    } ;

    if consumer.deploy { 

        // If deploy options is present then check if the private key was provided.
        let key = match consumer.private_key {
            Some(key) => key,
            None => return Err(anyhow!("\n ❌ Private Key Not Provided.\n Please provide unprefixed private key to deploy contract")),
        };   

        
        let data = get_deploy_data(
            from_network,
            consumer.contract_address, 
            DISpair::new(
                consumer.from_interpreter,
                consumer.from_store,
                consumer.from_deployer
            ) ,
            DISpair::new(
                consumer.to_interpreter,
                consumer.to_store,
                consumer.to_deployer
            ) ,
            consumer.transaction_hash
        ).await? ; 

        let (rpc_url,chain_id) = match consumer.to_network {
            RainNetworkOptions::Ethereum => {
                if consumer.ethereum_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --ethereum-rpc-url argument.")) ;
                }
                (consumer.ethereum_rpc_url.unwrap(),Ethereum::get_chain_id())
            } ,
            RainNetworkOptions::Polygon => {
                if consumer.polygon_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --polygon-rpc-url argument.")) ;
                }
                (consumer.polygon_rpc_url.unwrap(),Polygon::get_chain_id())
            },
            RainNetworkOptions::Mumbai => {
                if consumer.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --mumbai-rpc-url argument.")) ;
                }
                (consumer.mumbai_rpc_url.unwrap(),Mumbai::get_chain_id())
            },
            RainNetworkOptions::Fuji => {
                if consumer.fuji_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --fuji-rpc-url argument.")) ;
                }
                (consumer.fuji_rpc_url.unwrap(),Fuji::get_chain_id())
            }
        } ; 
            
        let provider = Provider::<Http>::try_from(rpc_url)
        .expect("\n❌Could not instantiate HTTP Provider"); 

        let wallet: LocalWallet = key.parse()?; 
        let client = SignerMiddleware::new_with_provider_chain(provider, wallet).await?;  

        let bytes_data = ethers::core::types::Bytes::from_str(&data).unwrap() ; 
        let chain_id = U64::from_dec_str(&chain_id).unwrap() ; 
        let tx = Eip1559TransactionRequest::new().data(bytes_data).chain_id(chain_id) ; 

        let tx = client.send_transaction(tx, None).await?;   

        let receipt = tx.confirmations(6).await?.unwrap();  

        let print_str = format!(
            "{}{}{}{}{}" ,
            String::from("\nContract Deployed !!\n#################################\n✅ Hash : "),
            &serde_json::to_string_pretty(&receipt.transaction_hash).unwrap().to_string(), 
            String::from("\nContract Address: "),
            serde_json::to_string_pretty(&receipt.contract_address.unwrap()).unwrap(),
            String::from("\n-----------------------------------\n")
        ) ; 
        println!(
           "{}",
           print_str
        ) ;

        Ok(())

    }else{ 

        
        let tx_data = get_deploy_data(
                        from_network ,
                        consumer.contract_address, 
                        DISpair::new(
                            consumer.from_interpreter,
                            consumer.from_store,
                            consumer.from_deployer
                        ) ,
                        DISpair::new(
                            consumer.to_interpreter,
                            consumer.to_store,
                            consumer.to_deployer
                        ) ,
                        consumer.transaction_hash
        ).await? ;

        println!("\n{}",tx_data) ;
        Ok(())

    }
     
}


#[cfg(test)] 
mod test { 

    use super::get_deploy_data ; 
    use crate::deploy::transaction::get_transaction_data;
    use crate::deploy::registry::RainNetworks;
    use crate::deploy::registry::Mumbai;
    use crate::deploy::registry::Fuji;
    use crate::deploy::DISpair;
    use std::env ;


    #[tokio::test]
    async fn test_rain_contract_deploy_data()  { 

        let mumbai_network = Mumbai::new(env::var("MUMBAI_RPC_URL").unwrap(), env::var("POLYGONSCAN_API_KEY").unwrap()) ; 
        let from_network: RainNetworks = RainNetworks::Mumbai(mumbai_network);  
        let contract_address = String::from("0x3cc6c6e888b4ad891eea635041a269c4ba1c4a63 ") ;  
        let tx_hash = None ; 

        let from_dis = DISpair {
            interpreter : Some(String::from("0x5f02c2f831d3e0d430aa58c973b8b751f3d81b38")) ,
            store : Some(String::from("0xa5d9c16ddfd05d398fd0f302edd9e9e16d328796")) , 
            deployer : Some(String::from("0xd3870063bcf25d5110ab9df9672a0d5c79c8b2d5"))
        } ; 

        let to_dis = DISpair {
            interpreter : Some(String::from("0xfd1da7eee4a9391f6fcabb28617f41894ba84cdc")),
            store : Some(String::from("0x9b8571bd2742ec628211111de3aa940f5984e82b")),  
            deployer : Some(String::from("0x3d7d894afc7dbfd45bf50867c9b051da8eee85e9")),
        } ;   

        let tx_data = get_deploy_data(
            from_network,
            contract_address,
            from_dis,
            to_dis,
            tx_hash
        ).await.unwrap() ;

        let expected_tx_hash = String::from("0x13b9895c7eb7311bbb22ef0a692b7b115c98c957514903e7c3a0e454e3389378") ; 
        // Reading environment variables
        let fuji_network = Fuji::new(env::var("FUJI_RPC_URL").unwrap(), env::var("SNOWTRACE_API_KEY").unwrap()) ; 
        let expected_network: RainNetworks = RainNetworks::Fuji(fuji_network) ;
        let expected_data = get_transaction_data(expected_network,expected_tx_hash).await.unwrap() ; 

        assert_eq!(tx_data,expected_data) ;

    }

     #[tokio::test]
    async fn test_non_rain_contract_deploy_data()  { 

        let mumbai_network = Mumbai::new(env::var("MUMBAI_RPC_URL").unwrap(), env::var("POLYGONSCAN_API_KEY").unwrap()) ; 
        let from_network: RainNetworks = RainNetworks::Mumbai(mumbai_network); 
        let contract_address = String::from("0x2c9f3204590765aefa7bee01bccb540a7d06e967") ;  
        let tx_hash = None ; 

        let from_dis = DISpair {
            interpreter : None,
            store : None,
            deployer : None,
        } ; 

        let to_dis = DISpair {
            interpreter : None,
            store : None,
            deployer : None,
        } ;   

        let tx_data = get_deploy_data(
            from_network,
            contract_address,
            from_dis,
            to_dis,
            tx_hash
        ).await.unwrap() ;

        let expected_tx_hash = String::from("0x2bcd975588b90d0da605c829c434c9e0514b329ec956375c32a97c87a870c33f") ; 
        let fuji_network = Fuji::new(env::var("FUJI_RPC_URL").unwrap(), env::var("SNOWTRACE_API_KEY").unwrap()) ; 
        let expected_network: RainNetworks = RainNetworks::Fuji(fuji_network) ;
        let expected_data = get_transaction_data(expected_network,expected_tx_hash).await.unwrap() ; 

        assert_eq!(tx_data,expected_data) ;

    }

    #[tokio::test]
    async fn test_tx_hash_deploy_data()  { 

        let mumbai_network = Mumbai::new(env::var("MUMBAI_RPC_URL").unwrap(), env::var("POLYGONSCAN_API_KEY").unwrap()) ; 
        let from_network: RainNetworks = RainNetworks::Mumbai(mumbai_network);  
        let contract_address = String::from("0x5f02c2f831d3e0d430aa58c973b8b751f3d81b38 ") ;  
        let tx_hash = Some(String::from("0xd8ff2d9381573294ce7d260d3f95e8d00a42d55a5ac29ff9ae22a401b53c2e19")) ; 

        let from_dis = DISpair {
            interpreter : None,
            store : None,
            deployer : None,
        } ; 

        let to_dis = DISpair {
            interpreter : None,
            store : None,
            deployer : None,
        } ;   

        let tx_data = get_deploy_data(
            from_network,
            contract_address,
            from_dis,
            to_dis,
            tx_hash
        ).await.unwrap() ;

        let expected_tx_hash = String::from("0x15f2f57f613a159d0e0a02aa2086ec031a2e56e0b9c803d0e89be78b4fa9b524") ; 
        let fuji_network = Fuji::new(env::var("FUJI_RPC_URL").unwrap(), env::var("SNOWTRACE_API_KEY").unwrap()) ; 
        let expected_network: RainNetworks = RainNetworks::Fuji(fuji_network) ; 
        let expected_data = get_transaction_data(expected_network,expected_tx_hash).await.unwrap() ; 

        assert_eq!(tx_data,expected_data) ;

    } 

}
