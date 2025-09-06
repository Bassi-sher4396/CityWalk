//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0 ;
import {Main} from "../src/MainContract.sol";
import {IPoolAddressesProvider} from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import {Script} from "forge-std/Script.sol";

contract Deploy is Script {
address public constant PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e ;
    function run() public returns(Main,address){
        vm.startBroadcast();
Main main = new Main(PROVIDER);
vm.stopBroadcast();
return (main,PROVIDER) ;
    }
}