use clap::{Parser, Subcommand};
use crate::deploy::{registry::{RainNetworkOptions, RainNetworks, Ethereum, Polygon, Mumbai, Fuji}, deployer::{expression_deployer, rain_contract}};
use anyhow::anyhow;

/// CLI utility to cross deploy Rain Contracts. 
#[derive(Subcommand)]
pub enum CrossDeploy{
    /// Deploy RainInterpreter, RainterpreterStore and RainterpreterExpresionDeployer corresponding to provided origin network RainterpreterExpresionDeployer.
    ExpressionDeployer(Deployer), 
    /// Deploy a Rain consumer contract.
    RainContract(RainContract),

}  

#[derive(Parser, Debug,Clone)]
pub struct Deployer{ 

    /// origin network to deploy contract from
    #[arg(short, long)]
    pub origin_network: RainNetworkOptions,  

    /// target network to dpeloy contract
    #[arg(short, long)]
    pub target_network: RainNetworkOptions , 

    /// origin network expression deployer address
    #[arg(short ='d' , long = "origin-deployer")]
    pub origin_deployer: String,  

    /// origin network transaction hash to source data from
    #[arg(short ='H' , long = "transaction-hash")]
    pub transaction_hash: Option<String> ,  
 
    /// private key (unprefixed) provided when deploy is set to true
    #[arg(short ='k' , long = "priavte-key" )]
    pub private_key: String,  

    /// mumbai rpc url, default read from env varibales
    #[arg(long,env)]
    pub mumbai_rpc_url: Option<String> , 

    /// polygon rpc url, default read from env varibales
    #[arg(long,env)]
    pub polygon_rpc_url: Option<String> ,  

    /// polygonscan api key, default read from env varibales
    #[arg(long,env)]
    pub polygonscan_api_key: Option<String> ,  

    /// ethereum rpc url, default read from env varibales
    #[arg(long,env)]
    pub ethereum_rpc_url: Option<String> ,  

    /// etherscan api key, default read from env varibales
    #[arg(long,env)]
    pub etherscan_api_key: Option<String> , 

    /// fuji rpc url, default read from env varibales
    #[arg(long,env)]
    pub fuji_rpc_url: Option<String> ,  

    /// snowtrace api key, default read from env varibales
    #[arg(long,env)]
    pub snowtrace_api_key: Option<String> ,

}   

impl Deployer {
    pub fn get_origin_network_details(&self) -> anyhow::Result<RainNetworks>{
        let from_network: RainNetworks = match self.origin_network.clone()  {
            RainNetworkOptions::Ethereum => {
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --ethereum-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --etherscan-api-key argument.")) ;
                }
                RainNetworks::Ethereum(Ethereum::new(self.ethereum_rpc_url.clone().unwrap(), self.etherscan_api_key.clone().unwrap()))
            } ,
            RainNetworkOptions::Polygon => {
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --polygon-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --polygonscan-api-key argument.")) ;
                }
                RainNetworks::Polygon(Polygon::new(self.polygon_rpc_url.clone().unwrap(), self.polygonscan_api_key.clone().unwrap()))
            },
            RainNetworkOptions::Mumbai => { 
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --mumbai-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --polygonscan-api-key argument.")) ;
                }  
                RainNetworks::Mumbai(Mumbai::new(self.mumbai_rpc_url.clone().unwrap(), self.polygonscan_api_key.clone().unwrap()))
            },
            RainNetworkOptions::Fuji => {
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --fuji-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --snowtrace-api-key argument.")) ;
                }
                RainNetworks::Fuji(Fuji::new(self.fuji_rpc_url.clone().unwrap(), self.snowtrace_api_key.clone().unwrap()))
            }
        } ; 
        Ok(from_network)
    } 

    pub fn get_target_network_details(&self) -> anyhow::Result<RainNetworks>{ 
        let to_network: RainNetworks = match self.target_network.clone()  {
            RainNetworkOptions::Ethereum => {
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --ethereum-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --etherscan-api-key argument.")) ;
                }
                RainNetworks::Ethereum(Ethereum::new(self.ethereum_rpc_url.clone().unwrap(), self.etherscan_api_key.clone().unwrap()))
            } ,
            RainNetworkOptions::Polygon => {
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --polygon-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --polygonscan-api-key argument.")) ;
                }
                RainNetworks::Polygon(Polygon::new(self.polygon_rpc_url.clone().unwrap(), self.polygonscan_api_key.clone().unwrap()))
            },
            RainNetworkOptions::Mumbai => { 
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --mumbai-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --polygonscan-api-key argument.")) ;
                }  
                RainNetworks::Mumbai(Mumbai::new(self.mumbai_rpc_url.clone().unwrap(), self.polygonscan_api_key.clone().unwrap()))
            },
            RainNetworkOptions::Fuji => {
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --fuji-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --snowtrace-api-key argument.")) ;
                }
                RainNetworks::Fuji(Fuji::new(self.fuji_rpc_url.clone().unwrap(), self.snowtrace_api_key.clone().unwrap()))
            }
        } ;  
        Ok(to_network)

    }

}

#[derive(Parser, Debug,Clone)]
pub struct RainContract{ 

    /// origin network to deploy contract from
    #[arg(short, long)]
    pub origin_network: RainNetworkOptions,  

    /// target network to dpeloy contract
    #[arg(short, long)]
    pub target_network: RainNetworkOptions ,  

    /// origin network expression deployer address
    #[arg(short ='d' , long = "origin-deployer")]
    pub origin_deployer: Option<String>,   

    /// origin network expression deployer address
    #[arg(short ='D' , long = "target-deployer")]
    pub target_deployer: Option<String>,   

    /// origin network transaction hash to source data from
    #[arg(short ='H' , long = "transaction-hash")]
    pub transaction_hash: Option<String> ,   

    /// origin network contract address
    #[arg(short ='c' , long = "contract-address")]
    pub contract_address: String , 

    /// private key (unprefixed) provided when deploy is set to true
    #[arg(short ='k' , long = "priavte-key" )]
    pub private_key: String, 

    /// mumbai rpc url, default read from env varibales
    #[arg(long,env)]
    pub mumbai_rpc_url: Option<String> , 

    /// polygon rpc url, default read from env varibales
    #[arg(long,env)]
    pub polygon_rpc_url: Option<String> ,  

    /// polygonscan api key, default read from env varibales
    #[arg(long,env)]
    pub polygonscan_api_key: Option<String> ,  

    /// ethereum rpc url, default read from env varibales
    #[arg(long,env)]
    pub ethereum_rpc_url: Option<String> ,  

    /// etherscan api key, default read from env varibales
    #[arg(long,env)]
    pub etherscan_api_key: Option<String> , 

    /// fuji rpc url, default read from env varibales
    #[arg(long,env)]
    pub fuji_rpc_url: Option<String> ,  

    /// snowtrace api key, default read from env varibales
    #[arg(long,env)]
    pub snowtrace_api_key: Option<String> ,

}

impl RainContract{
    pub fn get_origin_network_details(&self) -> anyhow::Result<RainNetworks>{
        let from_network: RainNetworks = match self.origin_network.clone()  {
            RainNetworkOptions::Ethereum => {
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --ethereum-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --etherscan-api-key argument.")) ;
                }
                RainNetworks::Ethereum(Ethereum::new(self.ethereum_rpc_url.clone().unwrap(), self.etherscan_api_key.clone().unwrap()))
            } ,
            RainNetworkOptions::Polygon => {
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --polygon-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --polygonscan-api-key argument.")) ;
                }
                RainNetworks::Polygon(Polygon::new(self.polygon_rpc_url.clone().unwrap(), self.polygonscan_api_key.clone().unwrap()))
            },
            RainNetworkOptions::Mumbai => { 
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --mumbai-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --polygonscan-api-key argument.")) ;
                }  
                RainNetworks::Mumbai(Mumbai::new(self.mumbai_rpc_url.clone().unwrap(), self.polygonscan_api_key.clone().unwrap()))
            },
            RainNetworkOptions::Fuji => {
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --fuji-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --snowtrace-api-key argument.")) ;
                }
                RainNetworks::Fuji(Fuji::new(self.fuji_rpc_url.clone().unwrap(), self.snowtrace_api_key.clone().unwrap()))
            }
        } ; 
        Ok(from_network)
    } 

    pub fn get_target_network_details(&self) -> anyhow::Result<RainNetworks>{ 
        let to_network: RainNetworks = match self.target_network.clone()  {
            RainNetworkOptions::Ethereum => {
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --ethereum-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --etherscan-api-key argument.")) ;
                }
                RainNetworks::Ethereum(Ethereum::new(self.ethereum_rpc_url.clone().unwrap(), self.etherscan_api_key.clone().unwrap()))
            } ,
            RainNetworkOptions::Polygon => {
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --polygon-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --polygonscan-api-key argument.")) ;
                }
                RainNetworks::Polygon(Polygon::new(self.polygon_rpc_url.clone().unwrap(), self.polygonscan_api_key.clone().unwrap()))
            },
            RainNetworkOptions::Mumbai => { 
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --mumbai-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --polygonscan-api-key argument.")) ;
                }  
                RainNetworks::Mumbai(Mumbai::new(self.mumbai_rpc_url.clone().unwrap(), self.polygonscan_api_key.clone().unwrap()))
            },
            RainNetworkOptions::Fuji => {
                if self.mumbai_rpc_url.is_none(){
                    return Err(anyhow!("\n ❌Please provide --fuji-rpc-url argument.")) ;
                }
                if self.polygonscan_api_key.is_none(){
                    return Err(anyhow!("\n ❌Please provide --snowtrace-api-key argument.")) ;
                }
                RainNetworks::Fuji(Fuji::new(self.fuji_rpc_url.clone().unwrap(), self.snowtrace_api_key.clone().unwrap()))
            }
        } ;  
        Ok(to_network)

    }


}
/// CLI function handler
pub async fn deploy(cross_deploy: CrossDeploy) -> anyhow::Result<()> {
    match cross_deploy {
        CrossDeploy::ExpressionDeployer(deployer) => {
            let _ = expression_deployer(deployer).await ; 
        } 
        CrossDeploy::RainContract(contract) => {
            let _ = rain_contract(contract).await ;
        }
    } 
    Ok(())

}



// #[derive(Parser, Debug)]
// pub struct CrossDeploy{
//     /// origin network to deploy contract from
//     #[arg(short, long = "from-network")]
//     pub origin_network: RainNetworkOptions,  

//     /// target network to dpeloy contract
//     #[arg(short, long = "to-network")]
//     pub to_network: RainNetworkOptions ,

//     /// origin network interpreter address
//     #[arg(short ='i' , long = "from-interpreter")]
//     pub from_interpreter: Option<String>,

//     /// origin network store address
//     #[arg(short ='s' , long = "from-store")]
//     pub from_store: Option<String>,

//     /// origin network expression deployer address
//     #[arg(short ='d' , long = "from-deployer")]
//     pub from_deployer: Option<String>, 

//     /// target network interpreter address
//     #[arg(short ='I' , long = "to-interpreter")]
//     pub to_interpreter: Option<String>,

//     /// target network store address
//     #[arg(short ='S' , long = "to-store")]
//     pub to_store: Option<String>,

//     /// target network expression deployer address
//     #[arg(short ='D' , long = "to-deployer")]
//     pub to_deployer: Option<String>,

//     /// origin network contract address
//     #[arg(short ='c' , long = "contract-address")]
//     pub contract_address: String ,

//     /// origin network transaction hash to source data from
//     #[arg(short ='H' , long = "transaction-hash")]
//     pub transaction_hash: Option<String> ,

//     /// Set to true to deploy contract to target network 
//     #[arg(long)]
//     pub deploy: bool, 

//     /// private key (unprefixed) provided when deploy is set to true
//     #[arg(short ='k' , long = "priavte-key" )]
//     pub private_key: Option<String>,  

//     /// mumbai rpc url, default read from env varibales
//     #[arg(long,env)]
//     pub mumbai_rpc_url: Option<String> , 

//     /// polygon rpc url, default read from env varibales
//     #[arg(long,env)]
//     pub polygon_rpc_url: Option<String> ,  

//     /// polygonscan api key, default read from env varibales
//     #[arg(long,env)]
//     pub polygonscan_api_key: Option<String> ,  

//     /// ethereum rpc url, default read from env varibales
//     #[arg(long,env)]
//     pub ethereum_rpc_url: Option<String> ,  

//     /// etherscan api key, default read from env varibales
//     #[arg(long,env)]
//     pub etherscan_api_key: Option<String> , 

//     /// fuji rpc url, default read from env varibales
//     #[arg(long,env)]
//     pub fuji_rpc_url: Option<String> ,  

//     /// snowtrace api key, default read from env varibales
//     #[arg(long,env)]
//     pub snowtrace_api_key: Option<String> ,
  
// } 


