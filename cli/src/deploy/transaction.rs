
use ethers::providers::{Provider, Middleware, Http} ;
use ethers::types::{H256, Bytes};
use std::str::FromStr;
use anyhow::Result;
use super::registry::RainNetworks; 
use anyhow::anyhow;

/// Returns transaction data for the provided transacion hash.
/// Supported transaction for only [RainNetworks].
/// # Example
/// ```
/// # use rain_cli_factory::deploy::transaction::get_transaction_data; 
/// # use rain_cli_factory::deploy::registry::RainNetworks; 
/// # use rain_cli_factory::deploy::registry::Mumbai;
/// use std::str::FromStr;
/// use ethers::types::{H160, H256}; 
/// # use std::env ;
/// 
/// async fn get_tx_data(){ 
///    // Network to retrieve data from
///    let mumbai_network = Mumbai::new(env::var("MUMBAI_RPC_URL").unwrap(), env::var("POLYGONSCAN_API_KEY").unwrap()) ; 
///    let from_network: RainNetworks = RainNetworks::Mumbai(mumbai_network);  
///    
///    // Transaction Hash 
///    let tx_hash = H256::from_str(&String::from("0xea76ed73832498c4293aa06aeca2899f2b5adca15d703b03690185ed829f3e72")).unwrap() ;   
///    
///    // Get transaction data
///    let tx_data = get_transaction_data(from_network,tx_hash).await ; 
/// }
pub async fn get_transaction_data(from_network : RainNetworks ,tx_hash : H256) -> Result<Bytes> { 

    let rpc_url = match from_network {
        RainNetworks::Ethereum(network) => {
            network.rpc_url
        },
        RainNetworks::Polygon(network) => {
            network.rpc_url
        }
        RainNetworks::Mumbai(network) => {
            network.rpc_url
        }
        RainNetworks::Fuji(network) => {
            network.rpc_url
        }
    } ; 

    let provider = Provider::<Http>::try_from(rpc_url)?;    

    let tx_result = provider.get_transaction(tx_hash).await ;  

    match tx_result {
        Ok(tx) => {
            match tx {
                Some(tx_data) => {
                    let data = tx_data.input ; 
                    Ok(data)
                } ,
                None => {
                    return Err(anyhow!("\n❌Transaction hash not found.\n Please make sure to provide correct hash.")) ;
                }
            }
        } ,
        Err(_) => {
            return Err(anyhow!("\n❌Network provider error")) ;
        }
    }

 

}  

// #[cfg(test)] 
// mod test { 

//     use super::get_transaction_data ; 
//     use crate::deploy::registry::RainNetworks;
//     use crate::deploy::registry::Mumbai;
//     use std::env ;


//     #[tokio::test]
//     async fn test_incorrect_hash()  {
//         let mumbai_network = Mumbai::new(env::var("MUMBAI_RPC_URL").unwrap(), env::var("POLYGONSCAN_API_KEY").unwrap()) ; 
//         let from_network: RainNetworks = RainNetworks::Mumbai(mumbai_network); 
//         let tx_hash = String::from("0xea76ed73832498c4293aa06aeca2899f2b5adca15d703b03690185ed829f3e72") ;   
//         let tx_data = get_transaction_data(from_network,tx_hash).await ; 
//         assert!(tx_data.is_err()) ;
//     } 

//     #[tokio::test]
//     async fn test_transaction_hash()  {
//         let mumbai_network = Mumbai::new(env::var("MUMBAI_RPC_URL").unwrap(), env::var("POLYGONSCAN_API_KEY").unwrap()) ; 
//         let from_network: RainNetworks = RainNetworks::Mumbai(mumbai_network);  
//         let tx_hash = String::from("0xea76ed73832498c4293aa06aeca2899f2b5adca15d703b03690185ed829f3e71") ;   
//         let tx_data = get_transaction_data(from_network,tx_hash).await ; 
//         assert!(tx_data.is_ok()) ;
//     }

// }

