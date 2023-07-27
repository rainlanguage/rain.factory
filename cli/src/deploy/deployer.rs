
use std::str::FromStr;
use std::{convert::TryFrom, sync::Arc};
use anyhow::anyhow;
use ethers::providers::{Provider, Http} ;
use ethers::core::abi::Abi ;
use ethers::core::types::H160; 
use ethers::contract::Contract;
use ethers::types::H256;


use crate::cli::deploy::{Deployer, RainContract};
use crate::deploy::deploy_contract;
use crate::deploy::dis::{DISpair, replace_dis_pair};
use crate::deploy::transaction::get_transaction_data;
use crate::subgraph::get_transaction_hash;

use super::registry::RainNetworks; 

use spinners::{Spinner, Spinners};

/// CLI function handler to cross deploy exxpression deployer
pub async fn expression_deployer(deployer_data: Deployer) -> anyhow::Result<()> {  

    let from_network = deployer_data.get_origin_network_details().unwrap() ;
    let to_network = deployer_data.get_target_network_details().unwrap() ; 

    let origin_deployer = match H160::from_str(&deployer_data.origin_deployer) {
        Ok(d) => d ,
        Err(_) => {
            return Err(anyhow!("\n ❌Incorrect Address Format Provided")) ;
        } 
    } ;

    let (interepreter_, store_) = get_interpreter_store(
        origin_deployer.clone(),from_network.clone()
    ).await.unwrap() ; 

    // Deploy Interpreter on Target Network
    let i_tx = get_transaction_hash(
        from_network.clone(),
        interepreter_.clone()
    ).await.unwrap() ;

    let i_data = get_transaction_data(
        from_network.clone(),
    i_tx).await.unwrap() ;

    let mut sp1 = Spinner::new(
        Spinners::from_str("Dots9").unwrap(),
        "Deploying RainInterpreter Contract...".into(),
    ); 

    let (i_tx_hash, i_address) = deploy_contract(
        to_network.clone(),
        deployer_data.private_key.clone(),i_data
    ).await.unwrap() ; 

    sp1.stop_with_message("Finished deploying RainInterpreter contract\n".into());

    let print_str = format!(
        "{}{}{}{}{}" ,
        String::from("\nInterpreter Deployed on target network !!\n#################################\n✅ Hash : "),
        format!("0x{}",hex::encode(i_tx_hash.as_bytes().to_vec())), 
        String::from("\nContract Address: "),
        format!("0x{}",hex::encode(i_address.as_bytes().to_vec())),
        String::from("\n-----------------------------------\n")
    ) ; 
    println!(
        "{}",
        print_str
    ) ;

    // Deploy Store
    let s_tx = get_transaction_hash(from_network.clone(),store_.clone()).await.unwrap() ;
    let s_data = get_transaction_data(from_network.clone(), s_tx).await.unwrap() ; 

    let mut sp = Spinner::new(
        Spinners::from_str("Dots9").unwrap(),
        "Deploying RainterpreterStore Contract...".into(),
    );  

    let (s_tx_hash, s_address) = deploy_contract(to_network.clone(),deployer_data.private_key.clone(),s_data).await.unwrap() ; 

    sp.stop_with_message("Finished deploying RainterpreterStore contract.\n".into());

    let print_str = format!(
        "{}{}{}{}{}" ,
        String::from("\nStore Deployed on target network !!\n#################################\n✅ Hash : "),
        format!("0x{}",hex::encode(s_tx_hash.as_bytes().to_vec())), 
        String::from("\nContract Address: "),
        format!("0x{}",hex::encode(s_address.as_bytes().to_vec())),
        String::from("\n-----------------------------------\n")
    ) ; 
    println!(
        "{}",
        print_str
    ) ;
 
    // Deploy Expression Deployer  
    let d_tx = match deployer_data.transaction_hash {
        Some(hash) => {
            match H256::from_str(&hash) {
                Ok(hash) => hash ,
                Err(_) => {
                    return Err(anyhow!("\n ❌Incorrect Transaction String Provided.")) ; 
                }
            } 
        } ,
        None => {
            get_transaction_hash(from_network.clone(),origin_deployer).await.unwrap()
        }
    } ; 
    let d_data = get_transaction_data(from_network.clone(), d_tx).await.unwrap() ;   
    let d_data = replace_dis_pair(
        d_data ,
        DISpair{
            interpreter : Some(interepreter_),
            store : Some(store_),
            deployer : None
        } ,
        DISpair{
            interpreter : Some(i_address),
            store : Some(s_address),
            deployer : None
        } 
    ).unwrap() ; 

    let mut sp = Spinner::new(
        Spinners::from_str("Dots9").unwrap(),
        "Deploying RainterpreterExpresionDeployer dontract...".into(),
    );

    let (d_tx_hash, d_address) = deploy_contract(to_network.clone(),deployer_data.private_key.clone(),d_data).await.unwrap() ;

    sp.stop_with_message("Finished deploying RainterpreterExpresionDeployer contract\n".into());
    
    let print_str = format!(
        "{}{}{}{}{}" ,
        String::from("\nExpression Deployer deployed on target network !!\n#################################\n✅ Hash : "),
        format!("0x{}",hex::encode(d_tx_hash.as_bytes().to_vec())), 
        String::from("\nContract Address: "),
        format!("0x{}",hex::encode(d_address.as_bytes().to_vec())),
        String::from("\n-----------------------------------\n")
    ) ; 
    println!(
        "{}",
        print_str
    ) ;

    Ok(())
} 

/// CLI function handler to cross deploy rain consumer contract
pub async fn rain_contract(contract: RainContract) -> anyhow::Result<()> {  
    
    // Get Origin Network Details
    let from_network = contract.get_origin_network_details().unwrap() ;

    // Get Target Network Details
    let to_network = contract.get_target_network_details().unwrap() ; 

    let contract_address = match H160::from_str(&contract.contract_address) {
        Ok(c) => c ,
        Err(_) => {
            return Err(anyhow!("\n ❌Incorrect Address Format Provided")) ;
        } 
    } ;
    
    // Check if transaction hash is provided
    let tx_hash = match contract.transaction_hash {
        Some(hash) => {
            match H256::from_str(&hash) {
                Ok(hash) => hash,
                Err(_) => {
                    return Err(anyhow!("\n ❌Incorrect Transaction Format Provided")) ;
                }
            }
        } ,
        None => {
            get_transaction_hash(from_network.clone(), contract_address.clone()).await?
        }
     } ;    

    let tx_data = get_transaction_data(from_network.clone(), tx_hash).await? ;

    let mut source_interpreter: Option<H160> = None ; 
    let mut source_store: Option<H160> = None ; 
    let mut source_deployer: Option<H160> = None ; 

    let mut target_interpreter: Option<H160> = None ; 
    let mut target_store: Option<H160> = None ; 
    let mut target_deployer: Option<H160> = None ; 
    
    // If both deployer are provided
    if contract.origin_deployer.is_some() && contract.target_deployer.is_some() {
        source_deployer = match H160::from_str(&contract.origin_deployer.clone().unwrap()) {
            Ok(d) => Some(d) ,
            Err(_) => {
                return Err(anyhow!("\n ❌Incorrect Address Format for Origin Deployer")) ;
            } 
        } ; 

        let(si,ss) = get_interpreter_store(
            source_deployer.unwrap(),
            from_network.clone()
        ).await.unwrap() ; 

        source_interpreter = Some(si);
        source_store = Some(ss); 

        // Get target IS 
        target_deployer = match H160::from_str(&contract.target_deployer.clone().unwrap()) {
            Ok(d) => Some(d) ,
            Err(_) => {
                return Err(anyhow!("\n ❌Incorrect Address Format for Target Deployer")) ;
            } 
        } ; 

        let (ti,ts) = get_interpreter_store(
            target_deployer.unwrap(),
            to_network.clone()
        ).await.unwrap() ;  

        target_interpreter = Some(ti) ;
        target_store = Some(ts) ;
        
    } 

    // Prepare Data
    let tx_data = replace_dis_pair(
        tx_data,
        DISpair { interpreter:source_interpreter , store: source_store , deployer: source_deployer},
        DISpair { interpreter: target_interpreter , store: target_store, deployer: target_deployer },
    ).unwrap() ; 

    let mut sp = Spinner::new(
        Spinners::from_str("Dots9").unwrap(),
        "Deploying Contract...".into(),
    );

    // Deploy Contract
    let (contract_hash, contract_address) = deploy_contract(
        to_network.clone(),
        contract.private_key,tx_data
    ).await.unwrap() ;  

    sp.stop_with_message("Finished deploying contract\n".into());

    let print_str = format!(
        "{}{}{}{}{}" ,
        String::from("\nContract Deployed on target network !!\n#################################\n✅ Hash : "),
        format!("0x{}",hex::encode(contract_hash.as_bytes().to_vec())), 
        String::from("\nContract Address: "),
        format!("0x{}",hex::encode(contract_address.as_bytes().to_vec())), 
        String::from("\n-----------------------------------\n")
    ) ; 
    println!(
        "{}",
        print_str
    ) ;  
     
    Ok(())
}  

/// Function to get Rainterpreter and RainterpreterStore corresponding to deployer
pub async fn get_interpreter_store(
    deployer_address: H160 ,
    network : RainNetworks
) -> anyhow::Result<(H160,H160)> { 


    let provider_url = match network {
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
 
    let abi: Abi= serde_json::from_str(r#"[{"inputs":[],"name":"store","outputs":[{"internalType":"contract IInterpreterStoreV1","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"interpreter","outputs":[{"internalType":"contract IInterpreterV1","name":"","type":"address"}],"stateMutability":"view","type":"function"}]"#)?;

    // connect to the network
    let client = Provider::<Http>::try_from(provider_url).unwrap();

    // create the contract object at the address
    let contract = Contract::new(deployer_address, abi, Arc::new(client));  
    
    let store: H160 = contract.method::<_, H160>("store", ())?.call().await? ; 
    let intepreter: H160 = contract.method::<_, H160>("interpreter", ())?.call().await? ;  

    Ok((intepreter,store))

} 

