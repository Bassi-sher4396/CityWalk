//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20MetaData.sol";
import {IPoolDataProvider} from "lib/aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {DataTypes} from "@aave/contracts/protocol/libraries/types/DataTypes.sol";
import {IPriceOracle} from "@aave/contracts/interfaces/IPriceOracle.sol";
import {IAToken} from "@aave/contracts/interfaces/IAToken.sol";
contract Oracle{
IPoolDataProvider public providerData ;
IPoolAddressesProvider public addressProvider;
IPool public pool ;
IPriceOracle public oracle ;
mapping(address=>uint256) public lll;
error hfTooLow();
struct TokenData{
    string symbol;
    address tokenAddress;
}
constructor ( address _addressProvider,address _pool){
addressProvider = IPoolAddressesProvider(_addressProvider);
providerData = IPoolDataProvider(addressProvider.getPoolDataProvider());
pool = IPool(_pool);
oracle = IPriceOracle(addressProvider.getPriceOracle());

}
function mostProfittableAsset() public view returns(TokenData memory){
    IPoolDataProvider.TokenData[] memory asla = providerData.getAllReservesTokens();
    uint256 diff ;
    TokenData memory tokendata;
    for(uint256 i =0 ; i <asla.length ;i++){
        TokenData memory tokenData = TokenData(asla[i].symbol,asla[i].tokenAddress) ;
        DataTypes.ReserveData memory reserve =   pool.getReserveData(tokenData.tokenAddress);
        uint256 depositRate = ((reserve.currentLiquidityRate*100)/1e27);
        uint256 borrowRate = ((reserve.currentVariableBorrowRate*100)/1e27) ;
        uint256 differenceInRates = depositRate-borrowRate;
if(differenceInRates >= diff ){
    diff = differenceInRates;
tokendata = tokenData ;
}
    }
    return  tokendata;
}
function getPriceAsset(address asset) public view returns (uint256) {
    uint256 price = oracle.getAssetPrice(asset); 
    uint256 decimals = IERC20Metadata(asset).decimals();
    return (price * (10 ** (18 - 8))) / (10 ** decimals);
}


function getAtokenAddress(address asset)public view returns(address) {
(address aToken,,) =  providerData.getReserveTokensAddresses(asset);
return aToken ;
}
function getInterest(uint256 amountToWithdraw ,address asset,address child,uint256 Principal) internal returns(uint256){
   Principal = Principal - lll[child] ;
DataTypes.ReserveData memory reserveData = pool.getReserveData(asset);
address aTokenAddress = reserveData.aTokenAddress;
uint256 Abalance = IAToken(aTokenAddress).balanceOf(child);
uint256 yield =  Abalance - Principal ;
uint256 interest = yield*amountToWithdraw/Principal;
 lll[child] += amountToWithdraw;

return interest ;
}
function checkLiquidityWithBorrow(uint256 amountToBeWithdrawn,address asset1,address asset2,address userChild,uint256 amountAlreadyWithdrawn, uint256 amountDeposited,uint256 Principal) public returns(uint256, uint256) {
    ( uint256 collateralBase, uint256 debtBase, , , uint256 ltv,  uint256 liquidationThreshold) = pool.getUserAccountData(userChild);

   
    amountToBeWithdrawn = amountToBeWithdrawn + (getInterest(amountToBeWithdrawn, asset1, userChild,Principal) / 2);

    
    uint256 reduceCollateral = (amountToBeWithdrawn * getPriceAsset(asset1)) / 1e18;
    uint256 leftCollateral = collateralBase - reduceCollateral;
 uint256 gt = getPriceAsset(asset2);
    uint256 bt = (leftCollateral * ltv) ;
    uint256 amountThatCanBeHeldBorrowed = bt / ( gt* 10000 / 1e18);

    
    uint256 currentDebtAmount = (debtBase * 1e18) / gt;

    uint256 token2AmountNeededToBeWithdrawn = currentDebtAmount - amountThatCanBeHeldBorrowed;

   uint256 tt = checkCustomLT(userChild);
    if ((leftCollateral * tt) / (amountThatCanBeHeldBorrowed * gt*10000) < 1) {
        revert hfTooLow();
    }

    return (amountThatCanBeHeldBorrowed, token2AmountNeededToBeWithdrawn);
}

// function giveTheInterestForTheProtocolAndTheUser(address asset) public {
// DataTypes.ReserveData memory reserve =  pool.getReserveData(asset);
//  uint256 depositRate = ((reserve.currentLiquidityRate*100)/1e27);
//         uint128 borrowRate = ((reserve.currentVariableBorrowRate*100)/1e27) ;
//         uint128 differenceInRates = depositRate-borrowRate;

// }
function checkCustomLT(address child) public returns(uint256) {
    (uint256 collateralBase ,uint256 currentDebtbase,,,uint256 ltv ,uint256 liquidationThreshhold) = pool.getUserAccountData(child);
    uint256 customLT = (ltv +  liquidationThreshhold)/2 ;
    return customLT ;
}
function fixHf(address child,address asset2) public returns(uint256){
    (uint256 collateralBase ,uint256 currentDebtbase,,,uint256 ltv ,uint256 liquidationThreshhold) = pool.getUserAccountData(child);
    uint256 Lt = checkCustomLT(child)/10000;
  uint256  requiredDebtBase = collateralBase*Lt ;
  uint256 extra = currentDebtbase - requiredDebtBase ;
 uint256 amount2ToWithdraw = (extra * 1e18) / getPriceAsset(asset2);
  return amount2ToWithdraw ; 
}
}