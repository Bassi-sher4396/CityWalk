//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {UserHandler} from "./UserHandler.sol";
import{ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol" ;
/*
*contract only accepts ETH
 */
contract Main is ReentrancyGuard {
mapping(address=>uint256) public amountDeposited ;
mapping(address=>address) public userChildren ;
mapping(address=>uint256) public amountWithdrawn ;
mapping(address=>uint256 ) public amountWithdrawnOnlyPrincipal ;
IPoolAddressesProvider public immutable i_provider;
IPool public immutable i_pool;
error AmountShouldNotBeZero();
error notDeposited();
error wihtdrawnAll();
error withdrawLess();
constructor(address provider){
i_provider = IPoolAddressesProvider(provider);
i_pool = IPool(i_provider.getPool());

}
// allots a new user handler to a user and checks whether it ha submitted any token or not 
//it requires user to send money to the contract
function CreateUserInvestment(address tokenToInvest , uint256 amountToInvest) public  {
    if(amountToInvest == 0){
        revert AmountShouldNotBeZero();
    }
    if(IERC20(tokenToInvest).balanceOf(address(this)) < amountToInvest){
        revert ();
    }
    amountDeposited[msg.sender] += amountToInvest ;


if(userChildren[msg.sender] == address(0)){
    UserHandler child = new UserHandler(address(i_provider),address(i_pool),msg.sender,tokenToInvest,amountToInvest,address(this));
userChildren[msg.sender] = address(child) ;
}
supplyTokenToAave(tokenToInvest,amountToInvest,msg.sender);
}

function supplyTokenToAave(address tokenToInvest , uint256 amountToInvest , address user) internal {
    IERC20(tokenToInvest).approve(address(i_pool), amountToInvest);
i_pool.supply(tokenToInvest, amountToInvest, userChildren[user], 0);
UserHandler(userChildren[user]).borrowFromAave();

}
function withdrawDeposit(uint256 amount , address asset) public nonReentrant {
    if(amountDeposited[msg.sender] == 0){
        revert notDeposited();
    }
    if(amount >= amountDeposited[msg.sender]){
        revert ();
    }
    if(amountWithdrawnOnlyPrincipal[msg.sender] >= amountDeposited[msg.sender] ){
        revert wihtdrawnAll();
    }
    if(amount > amountDeposited[msg.sender]-amountWithdrawnOnlyPrincipal[msg.sender]){
       amount =  amountDeposited[msg.sender]-amountWithdrawnOnlyPrincipal[msg.sender] ;
    }
    
    amountWithdrawnOnlyPrincipal[msg.sender] += amount ;
  uint256 _amountWithdrawn =  UserHandler(userChildren[msg.sender]).withdraw(amount, amountWithdrawn[msg.sender],amountDeposited[msg.sender]);
   amountWithdrawn[msg.sender] += _amountWithdrawn ;
    if(amountWithdrawnOnlyPrincipal[msg.sender] == amountDeposited[msg.sender]){
        UserHandler(userChildren[msg.sender]).finish();
    }
    UserHandler child = UserHandler(userChildren[msg.sender]);
    if(child.checkCustomHealthFactor()<1e18){
        child.liquidate();
    }
}
  
}






