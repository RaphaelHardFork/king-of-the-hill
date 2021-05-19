// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol";

/** 
 * @title KingOfTheHill
 * @author Raphael Pellet
 * @custom:rules The owner initiate an amount, then gamers have to pay the double of the amount and wait 20 block to win.
 * In this version:
 * Name of variables changed:
 *      - _gamers => _gamersRewards
 *      - _winners => _jackpotOwner
 * 
 * Default fixed:
 *  - jackpotx3 when a player follow the jackpot instead of x2
 *  - event JackpotWinned as been added in the _gameOver function
 * 
 * @notice deployed at 0xC6353cfbF7990E247492c07484c8C978d445183F on Rinkeby
 * */
 
 contract KingOfTheHill {
     using Address for address payable;
     
     // storage
     address private _owner;
     mapping (address => uint256) private _gamersRewards;
     uint256 private _jackpot;
     address private _jackpotOwner;
     uint256 private _gameBlock;
     uint256 private _numberOfBlocks;
     
    /**
     *@notice The owner must initiate the jackpot at 1 finney or more (constructor)
     * */
     constructor(address owner_, uint256 numberOfBlocks_) payable {
         require(msg.value >= 1000000 gwei, "KingOfTheHill: This contract must be deployed with at least 1 finney.");
         _owner = owner_;
         _jackpot = msg.value;
         _numberOfBlocks = numberOfBlocks_;
     }
     
     // event
     event JackpotCalled(address indexed player, uint256 newJackpot);
     event JackpotIncreased(uint256 jackpot, uint256 newJackpot);
     event JackpotWithdrew(address indexed, uint256 jackpot);
     event JackpotWinned(address indexed, uint256 jackpot);
     
     // modifier
     modifier onlyOwner() {
         require(msg.sender == _owner, "KingOfTheHill: You are not allowed to use this function.");
         _;
     }
     
     /**
      * @dev The three following function update variables if the game is over by calling the _gameOver function (see below).
      *
      * @dev This function is the function to play the game. Sender have to pay to activate the function, sender have to pay the
      * jackpotx2 at least to call the function. If sender send more than 2xjackpot, the rest is refund.
      * If _gameBlock is = 0, this mean the game is not started yet. In this case the _jackpotOwner is set to _owner, this allow 
      * to prevent that the _owner call this function and also if the former _jackpotOwner want to launch another turn.
      * 
      * If the game is over the function _gameOver is called (see below).
      * The _jackpotOwner cannot call this function another time.
      * */
     function followJackpot() external payable {
        if (_gameBlock == 0) {
            _jackpotOwner = _owner;
        } else if (block.number >= _gameBlock + _numberOfBlocks) {
             _gameOver(msg.sender);
         }
         require(msg.sender != _jackpotOwner, "KingOfTheHill: You cannot increase the jackpot while you are the winner.");
         require(msg.value >= _jackpot*2, "KingOfTheHill: You have to pay the double of the jackpot, the rest is refund.");
         _gameBlock = block.number;
         _jackpotOwner = msg.sender;
         uint256 rest = msg.value - (_jackpot*2);
         _jackpot *= 3;                                 // Attention => jackpot x2 mais devrait être x3 (à tester) ou (+ jackpotx2)
         payable(msg.sender).sendValue(rest);
         emit JackpotCalled(msg.sender,_jackpot);
     }
     
     /**
      * @dev This function allow to the owner to increase the jackpot.
      * If the game is over the function _gameOver is called (see below).
      * This function can be called only if the game is not started.
      * This function is set to increase the jackpot in case this latter is too low to attract.
      * */
     function increaseJackpot() external payable onlyOwner {
         if (block.number >= _gameBlock + _numberOfBlocks && _gameBlock != 0) {
             _gameOver(msg.sender);
         }
         require(_gameBlock == 0, "KingOfTheHill: You cannot increase the jackpot while the game is running.");
         emit JackpotIncreased(_jackpot, _jackpot+msg.value);
         _jackpot+=msg.value;
     }
     
     /**
      * @dev This function is called to withdraw the rewards. As the other above function, if the game 
      * is over the function _gameOver is called (see below).
      * So if the _jackpotOwner call this function just after the game is done, by calling _gameOver, the balance of the 
      * _jackpotOwner will be updated.
      * */
     function withdrawJackpot() public {
         if (block.number >= _gameBlock + _numberOfBlocks && _gameBlock != 0) {
             _gameOver(msg.sender);
         }
         require(_gamersRewards[msg.sender] != 0, "KingOfTheHill: You have nothing to claim..");
         uint256 earned = _gamersRewards[msg.sender];
         _gamersRewards[msg.sender] = 0;
         payable(msg.sender).sendValue(earned);
         emit JackpotWithdrew(msg.sender, earned);
     }
     
      /**
       * @dev This function is set to view the actual jackpot (even if the game is over).
       * But the new jackpot (after the game is done) is an estimation fixed at 10% of the old jackpot.
       * */
     function jackpotToFollow() public view returns (uint256) {
         if (block.number >= _gameBlock + _numberOfBlocks && _gameBlock != 0) {
             return (_jackpot*10)/100;
         } else {
             return _jackpot;
         }
     }
     
     /**
      * @dev Return the number of block that we must wait. 
      * If it returns zero, this mean the game is over or not started yet
      * */
     function blocksBeforeWin() public view returns (uint256) {
         if (block.number >= _gameBlock + _numberOfBlocks) {
             return 0;
         }else{
             return (_gameBlock + _numberOfBlocks) - block.number;
         }
     }
     
     /**
      * @dev Return the address of the _jackpotOwner.
      * If the game is done, the former _jackpotOwner is still display with this function. Until the game is re launched.
      * */
     function currentWinner() public view returns (address) {
         return _jackpotOwner;
     }
     
     /**
      * @dev Return the balance of the address in parameter
      * */
     function balanceOf(address account) public view returns (uint256) {
         return _gamersRewards[account];
     }
     
     /**
      * @dev This private function is called to update variables. The following variables are updated:
      *     - gameBlock is set to zero to report that the game is over and waiting another return.
      *     - balance of the last _jackpotOwner and the _owner are updated.
      *     - _jackpot is updated with a new seed
      * 
      * Seed calculation: the two rewards (owner and jackpotOwner) and the seed are splitted differently 
      * depends on who call the function. There are three case:
      * (Seed / Owner gain / JackpotOwner gain -- in %)
      *     - the owner call this function: 10 / 10 / 80
      *     - the jackpotOwner call this function: 5 / 5 / 90
      *     - the next player call this function: 8 / 8 / 86
      * */
     function _gameOver(address caller) private {
         uint256 amount;
         if (caller == _owner) {
             amount = 10;
         } else if (caller == _jackpotOwner){
             amount = 5;
         } else {
             amount = 8;
         }
         uint256 seed = (_jackpot*amount)/100;
         _gamersRewards[_jackpotOwner] += _jackpot-(seed*2);
         _gamersRewards[_owner] += seed;
         emit JackpotWinned(_jackpotOwner, _jackpot);
         _jackpot = seed;
         _gameBlock = 0;
     }
 }