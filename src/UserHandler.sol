//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0 ;
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IAToken} from "@aave/contracts/interfaces/IAToken.sol";
import {Oracle} from "./Oracle.sol";
import {DataTypes}  from "@aave/contracts/protocol/libraries/types/DataTypes.sol"; 
contract UserHandler {

IPool public immutable i_pool;
uint256 public Principal ;
address public borrowedToken ;
address public USER;
address public token1;
error noBalance();
error healthFactorFine();
error HFStillTooLow();
address public main ; 

Oracle public oracle;
constructor(address _provider,address _pool ,address user , address _token1,uint amountdeposit,address _main){

i_pool = IPool(_pool);
USER = user;
token1 = _token1 ;

Principal = amountdeposit ;
main=_main;
oracle= new Oracle(_provider,_pool);
}


function borrowTokenAddress() public   returns(address)  {
    Oracle.TokenData memory tokenData = oracle.mostProfittableAsset();
    address token = tokenData.tokenAddress ;
    borrowedToken = token ;
return token ;
}
function calclateTheAmountUserCouldBorrow() public  returns(uint256) {
   (,,uint256 availableBorrowBase ,,,) = i_pool.getUserAccountData(address(this));
   uint256 priceToken = oracle.getPriceAsset(borrowTokenAddress());
  uint256 amountThatCanBeBorrowed = (availableBorrowBase * 1e18) / priceToken;

   return amountThatCanBeBorrowed;
}
function borrowFromAave() public  {
    i_pool.borrow(borrowTokenAddress(), calclateTheAmountUserCouldBorrow(), 2, 0,address(this));
    reInvestIntoAave(calclateTheAmountUserCouldBorrow());
}
function reInvestIntoAave(uint256 amount) public {
   IERC20(borrowedToken).approve(address(i_pool), amount);
   i_pool.supply(borrowedToken, amount, address(this), 0);
   i_pool.setUserUseReserveAsCollateral(borrowedToken , false);
}
function withdraw(uint256 amount , uint256 amountAlreadyWithdrawn,uint256 amountDeposited) public returns(uint256) {
     if(msg.sender!=main){revert ();}
    (uint256 amountToBeRepayedToAave,uint256 token1WithdrawAmount) = oracle.checkLiquidityWithBorrow(amount, token1, borrowedToken, address(this),amountAlreadyWithdrawn,amountDeposited,Principal);
    i_pool.withdraw(borrowedToken, amountToBeRepayedToAave, address(this));
    IERC20(borrowedToken).approve(address(i_pool),amountToBeRepayedToAave );
i_pool.repay(borrowedToken, amountToBeRepayedToAave, 2, address(this));
i_pool.withdraw(token1 , token1WithdrawAmount, USER);
return token1WithdrawAmount ;
}
//at the end when the user has received the principal amount he invested in our protocol along with the spcific interest then evrything is clear and all the remaing withdrawals and assets are tken and transferred to main contract 
function finish() public{
     if(msg.sender!=main){revert ();}
  uint256 startbalance =  IERC20(borrowedToken).balanceOf(address(this));
    i_pool.withdraw(borrowedToken, type(uint256).max, address(this));
    uint256 endBalance = IERC20(borrowedToken).balanceOf(address(this));
    IERC20(borrowedToken).approve(address(i_pool), endBalance-startbalance);
     (,uint256 debtBase,,,,) = i_pool.getUserAccountData(address(this));
    i_pool.repay(borrowedToken,debtBase , 2, address(this));
   (,debtBase,,,,) = i_pool.getUserAccountData(address(this));
    if(debtBase == 0){
    i_pool.withdraw(token1, type(uint256).max, main);}
IERC20(borrowedToken).transfer(main, IERC20(borrowedToken).balanceOf(address(this)));
IERC20(token1).transfer(main, IERC20(token1).balanceOf(address(this)));
}
function liquidate() public {
    if(msg.sender!=main){revert ();}
if(checkCustomHealthFactor() >= 1e18){
    revert healthFactorFine();
}
uint256 removeAmount = oracle.fixHf(address(this), borrowedToken);
i_pool.withdraw(borrowedToken, removeAmount, address(this));
IERC20(borrowedToken).approve(address(i_pool), removeAmount);
i_pool.repay(borrowedToken, removeAmount, 2, address(this));
if(checkCustomHealthFactor() < 1e18){
    revert HFStillTooLow() ;
}
}
function checkCustomHealthFactor() public returns(uint256){
    (uint256 collateralBase ,uint256 currentDebtbase,,, ,) = i_pool.getUserAccountData(address(this));
uint256 lt = oracle.checkCustomLT(address(this))/10000;
uint256 hf = (collateralBase*lt*1e18)/currentDebtbase ; 
return hf ;
}
} 