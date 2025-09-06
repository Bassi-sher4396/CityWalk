//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {Test} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {Main} from "../src/MainContract.sol";
import {UserHandler} from "../src/UserHandler.sol";
import {Oracle} from "../src/Oracle.sol"; 

contract testContract is Test {
    Main public main ;
Deploy public deploy ;
address public provider ;
    function setUp() external {
        deploy = new Deploy();
       (main,provider) =  deploy.run();
    }
}