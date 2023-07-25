//! # Deploy Crate
//!
//! Deploy crate is a collection of utilities to cross deploy a contract (specifically Rain Contracts)
//! to other supported chains.

use anyhow::Result;
use crate::{subgraph::get_transaction_hash, deploy::registry::RainNetworks};
use self::{transaction::get_transaction_data, dis::{DISpair, replace_dis_pair}}; 
use ethers::{providers::{Provider, Middleware, Http}, types::{H160, H256, Bytes}} ; 
use ethers::{signers::LocalWallet, types::{Eip1559TransactionRequest, U64}, prelude::SignerMiddleware};

pub mod registry; 


pub mod transaction; 
pub mod dis; 
pub mod deployer; 


/// Builds and returns contract deployment data for the provided target network [DISpair].
/// Optional transaction hash as an argument can be provided, which is recommended for Non-Rain contracts.
/// Returns deployment data for any contract without a constructor argument. 
/// For contracts which have constructor arguments the integrity of the returned data cannot be ensured.  
/// Returned data can directly be submitted via a signer to the blockchain. Refer [deploy_contract].
/// 
/// # Example 
/// ```rust
///  use rain_cli_factory::deploy::dis::DISpair;
///  use rain_cli_factory::deploy::get_deploy_data; 
///  use rain_cli_factory::deploy::registry::RainNetworks; 
///  use rain_cli_factory::deploy::registry::Mumbai; 
///  use std::str::FromStr;
///  use ethers::types::{H160, H256}; 
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
///    let contract_address = H160::from_str(&contract_address).unwrap() ;  
///     
///    let tx_hash = String::from("0xc215bf3dc7440687ca20e028158e58640eeaec72d6fe6738f6d07843835c2cde") ;
///    let tx_hash = H256::from_str(&tx_hash).unwrap() ;
///    let tx_hash = Some(tx_hash) ;
///    // Optional transaction hash can also be provided
///    
///    // Origin network DISpair
///    let from_dis = DISpair {
///        interpreter : Some(H160::from_str(&String::from("0x5f02c2f831d3e0d430aa58c973b8b751f3d81b38")).unwrap()),
///        store : Some(H160::from_str(&String::from("0xa5d9c16ddfd05d398fd0f302edd9e9e16d328796")).unwrap()),
///        deployer : Some(H160::from_str(&String::from("0xd3870063bcf25d5110ab9df9672a0d5c79c8b2d5")).unwrap()),
///   } ; 
///    
///    let to_dis = DISpair {
///        interpreter : Some(H160::from_str(&String::from("0xfd1da7eee4a9391f6fcabb28617f41894ba84cdc")).unwrap()),
///        store : Some(H160::from_str(&String::from("0x9b8571bd2742ec628211111de3aa940f5984e82b")).unwrap()),
///        deployer : Some(H160::from_str(&String::from("0x3d7d894afc7dbfd45bf50867c9b051da8eee85e9")).unwrap()),
///   } ; 
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
#[allow(dead_code)]
pub async fn get_deploy_data(
    from_network : RainNetworks ,
    contract_address : H160 ,
    from_dis : DISpair , 
    to_dis : DISpair ,
    tx_hash : Option<H256>
) -> Result<Bytes> {  

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

/// Submits the contract deployment transaction to the network via the signer
/// * `data` - ethers::types::bytes representing the contract deployment data.
/// * `key` - Private Key of the account used to sign transaction.
/// * `network` - Network to deploy contract to.
pub async fn deploy_contract(
    network : RainNetworks,
    key : String ,
    data : Bytes
) -> anyhow::Result<(H256,H160)> { 

    let (provider_url,chain_id) = match network {
        RainNetworks::Ethereum(network) => {
            (network.rpc_url,network.chain_id)
        },
        RainNetworks::Polygon(network) => {
            (network.rpc_url,network.chain_id)
        }
        RainNetworks::Mumbai(network) => {
            (network.rpc_url,network.chain_id)
        }
        RainNetworks::Fuji(network) => {
            (network.rpc_url,network.chain_id)
        }
    } ; 
        
    let provider = Provider::<Http>::try_from(provider_url)
    .expect("\n❌Could not instantiate HTTP Provider"); 

    let wallet: LocalWallet = key.parse()?; 
    let client = SignerMiddleware::new_with_provider_chain(provider, wallet).await?;  

    let chain_id = U64::from_dec_str(&chain_id).unwrap() ; 
    let tx = Eip1559TransactionRequest::new().data(data).chain_id(chain_id) ; 

    let tx = client.send_transaction(tx, None).await?;   

    let receipt = tx.confirmations(6).await?.unwrap();  

    Ok(( receipt.transaction_hash , receipt.contract_address.unwrap()))
    
}

// #[cfg(test)] 
// mod test { 

//     use super::get_deploy_data ; 
//     use crate::deploy::transaction::get_transaction_data;
//     use crate::deploy::registry::RainNetworks;
//     use crate::deploy::registry::Mumbai;
//     use crate::deploy::registry::Fuji;
//     use crate::deploy::DISpair;
//     use std::env ;


//     #[tokio::test]
//     async fn test_rain_contract_deploy_data()  { 

//         let mumbai_network = Mumbai::new(env::var("MUMBAI_RPC_URL").unwrap(), env::var("POLYGONSCAN_API_KEY").unwrap()) ; 
//         let from_network: RainNetworks = RainNetworks::Mumbai(mumbai_network);  
//         let contract_address = String::from("0x3cc6c6e888b4ad891eea635041a269c4ba1c4a63 ") ;  
//         let tx_hash = None ; 

//         let from_dis = DISpair {
//             interpreter : Some(String::from("0x5f02c2f831d3e0d430aa58c973b8b751f3d81b38")) ,
//             store : Some(String::from("0xa5d9c16ddfd05d398fd0f302edd9e9e16d328796")) , 
//             deployer : Some(String::from("0xd3870063bcf25d5110ab9df9672a0d5c79c8b2d5"))
//         } ; 

//         let to_dis = DISpair {
//             interpreter : Some(String::from("0xfd1da7eee4a9391f6fcabb28617f41894ba84cdc")),
//             store : Some(String::from("0x9b8571bd2742ec628211111de3aa940f5984e82b")),  
//             deployer : Some(String::from("0x3d7d894afc7dbfd45bf50867c9b051da8eee85e9")),
//         } ;   

//         let tx_data = get_deploy_data(
//             from_network,
//             contract_address,
//             from_dis,
//             to_dis,
//             tx_hash
//         ).await.unwrap() ;

//         let expected_tx_hash = String::from("0x13b9895c7eb7311bbb22ef0a692b7b115c98c957514903e7c3a0e454e3389378") ; 
//         // Reading environment variables
//         let fuji_network = Fuji::new(env::var("FUJI_RPC_URL").unwrap(), env::var("SNOWTRACE_API_KEY").unwrap()) ; 
//         let expected_network: RainNetworks = RainNetworks::Fuji(fuji_network) ;
//         let expected_data = get_transaction_data(expected_network,expected_tx_hash).await.unwrap() ; 

//         assert_eq!(tx_data,expected_data) ;

//     }

//      #[tokio::test]
//     async fn test_non_rain_contract_deploy_data()  { 

//         let mumbai_network = Mumbai::new(env::var("MUMBAI_RPC_URL").unwrap(), env::var("POLYGONSCAN_API_KEY").unwrap()) ; 
//         let from_network: RainNetworks = RainNetworks::Mumbai(mumbai_network); 
//         let contract_address = String::from("0x2c9f3204590765aefa7bee01bccb540a7d06e967") ;  
//         let tx_hash = None ; 

//         let from_dis = DISpair {
//             interpreter : None,
//             store : None,
//             deployer : None,
//         } ; 

//         let to_dis = DISpair {
//             interpreter : None,
//             store : None,
//             deployer : None,
//         } ;   

//         let tx_data = get_deploy_data(
//             from_network,
//             contract_address,
//             from_dis,
//             to_dis,
//             tx_hash
//         ).await.unwrap() ;

//         let expected_tx_hash = String::from("0x2bcd975588b90d0da605c829c434c9e0514b329ec956375c32a97c87a870c33f") ; 
//         let fuji_network = Fuji::new(env::var("FUJI_RPC_URL").unwrap(), env::var("SNOWTRACE_API_KEY").unwrap()) ; 
//         let expected_network: RainNetworks = RainNetworks::Fuji(fuji_network) ;
//         let expected_data = get_transaction_data(expected_network,expected_tx_hash).await.unwrap() ; 

//         assert_eq!(tx_data,expected_data) ;

//     }

//     #[tokio::test]
//     async fn test_tx_hash_deploy_data()  { 

//         let mumbai_network = Mumbai::new(env::var("MUMBAI_RPC_URL").unwrap(), env::var("POLYGONSCAN_API_KEY").unwrap()) ; 
//         let from_network: RainNetworks = RainNetworks::Mumbai(mumbai_network);  
//         let contract_address = String::from("0x5f02c2f831d3e0d430aa58c973b8b751f3d81b38 ") ;  
//         let tx_hash = Some(String::from("0xd8ff2d9381573294ce7d260d3f95e8d00a42d55a5ac29ff9ae22a401b53c2e19")) ; 

//         let from_dis = DISpair {
//             interpreter : None,
//             store : None,
//             deployer : None,
//         } ; 

//         let to_dis = DISpair {
//             interpreter : None,
//             store : None,
//             deployer : None,
//         } ;   

//         let tx_data = get_deploy_data(
//             from_network,
//             contract_address,
//             from_dis,
//             to_dis,
//             tx_hash
//         ).await.unwrap() ;

//         let expected_tx_hash = String::from("0x15f2f57f613a159d0e0a02aa2086ec031a2e56e0b9c803d0e89be78b4fa9b524") ; 
//         let fuji_network = Fuji::new(env::var("FUJI_RPC_URL").unwrap(), env::var("SNOWTRACE_API_KEY").unwrap()) ; 
//         let expected_network: RainNetworks = RainNetworks::Fuji(fuji_network) ; 
//         let expected_data = get_transaction_data(expected_network,expected_tx_hash).await.unwrap() ; 

//         assert_eq!(tx_data,expected_data) ;

//     } 

// }
