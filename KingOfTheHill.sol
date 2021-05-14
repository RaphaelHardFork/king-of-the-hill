// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol";

/** 
 * @title KingOfTheHill
 * @author Raphael Pellet
 * @custom:rules The owner initiate an amount, then gamers have to pay the double of the amount and wait 20 block to win.
 * @notice in this version the number of block is set to 20 (~5min).
 * The owner must initiate the jackpot at 1 finney or more (constructor)
 * */
 
 contract KingOfTheHill {
     using Address for address payable;
     
     // storage
     address private _owner;
     mapping (address => uint256) private _gamers;
     uint256 private _jackpot;
     address private _winner;
     uint256 private _gameBlock;
     
     
     // constructor
     constructor(address owner_) payable {
         require(msg.value >= 1000000 gwei, "KingOfTheHill: This contract must be deployed with at least 1 finney.");
         _owner = owner_;
         _jackpot = msg.value;
     }
     
     // event
     event JackpotCalled(address indexed player, uint256 newJackpot);
     event JackpotIncreased(uint256 jackpot, uint256 newJackpot);
     event JackpotWithdrew(address indexed, uint256 jackpot);
     
     // modifier
     modifier onlyOwner() {
         require(msg.sender == _owner, "KingOfTheHill: You are not allowed to use this function.");
         _;
     }
     
     /**
      * @dev There are three important function : 
      *     - followJackpot: this is the function to play the game. Sender have to pay at least 2x the jackpot (the rest is refund).
      *     When this function is activate for the first time, the game starts the count (number of blocks).
      *     The owner cannot initiate the game (the first follow).
      *     One address cannot follow the jackpot twice time in a row.
      * 
      *     - increaseJackpot: this function allow to increase the jackpot IF the game is not started yet.
      *     Only the owner can call this function. This function is set to increase the jackpot in case the seed jackpot is too
      *     low to attract players.
      * 
      *     - withdrawJackpot: players can call this function to withdraw their jackpot.
      *     This function work only 
      * 
      * For all these three function, the states are actualised with de _gameOver() function if the game is over.
      * So winner can withdraw their jackpot by calling the function withdrawJackpot(), states will be updated during the call.
      * If a player follow the jackpot just after the game is over, the new jackpot to follow is updated during the call of the function.
      * */
     function followJackpot() external payable {
        if (_gameBlock == 0) {
            _winner = _owner;
        } else if (block.number >= _gameBlock + 20) {
             _gameOver();
         }
         require(msg.sender != _winner, "KingOfTheHill: You cannot increase the jackpot while you are the winner.");
         require(msg.value >= _jackpot*2, "KingOfTheHill: You have to pay the double of the jackpot, the rest is refund.");
         _gameBlock = block.number;
         _winner = msg.sender;
         uint256 rest = msg.value - (_jackpot*2);
         _jackpot *= 2;
         payable(msg.sender).sendValue(rest);
         emit JackpotCalled(msg.sender,_jackpot);
     }
     
     function increaseJackpot() external payable onlyOwner {
         if (block.number >= _gameBlock + 20 && _gameBlock != 0) {
             _gameOver();
         }
         require(_gameBlock == 0, "KingOfTheHill: You cannot increase the jackpot while the game is running.");
         emit JackpotIncreased(_jackpot, _jackpot+msg.value);
         _jackpot+=msg.value;
     }
     
     function withdrawJackpot() public {
         if (block.number >= _gameBlock + 20 && _gameBlock != 0) {
             _gameOver();
         }
         require(_gamers[msg.sender] != 0, "KingOfTheHill: You have nothing to claim..");
         uint256 earned = _gamers[msg.sender];
         _gamers[msg.sender] = 0;
         payable(msg.sender).sendValue(earned);
         emit JackpotWithdrew(msg.sender, earned);
     }
     
     /**
      * @dev There are four getter functions in this contract:
      *     - blocksBeforeWin: This return the number of block remaining before the current winner win the jackpot.
      *     
      *     - currentWinner: This return the last address who follow the jackpot.
      * 
      *     - jackpotToFollow: This return the jackpot witch has to be paid to follow. 
      *     This function take into account if the game is over or not.
      * 
      *     - balanceOf: By imput an address you can see if the player has something to claim.
      *     CAREFUL this function is not updated automatically (it must call one of the function calling _gameOver())
      * */
     function jackpotToFollow() public view returns (uint256) {
         if (block.number >= _gameBlock + 20 && _gameBlock != 0) {
             return (_jackpot*10)/100;
         } else {
             return _jackpot;
         }
     }
     
     function blocksBeforeWin() public view returns (uint256) {
         if (block.number >= _gameBlock + 20) {
             return 0;
         }else{
             return (_gameBlock+20) - block.number;
         }
     }
     
     function currentWinner() public view returns (address) {
         return _winner;
     }
     
     function balanceOf(address account) public view returns (uint256) {
         return _gamers[account];
     }
     
     /**
      * If the game is over the following states are updated:
      *     - the old jackpot is split between:
      *         - the new jackpot (the seed jackpot, 10% of the jackpot)
      *         - the balance of the winner (80% of the jackpot)
      *         - the balance of the owner (10% of the jackpot)
      *     - gameBlock is set at zero to simulate a new gameBlock  
      *     - the winner is set to the owner to prevent a new game initiated by the owner
      * */
     
     function _gameOver() private {
         uint256 seed = (_jackpot*10)/100;
         _gamers[_winner] += _jackpot-(seed*2);
         _gamers[_owner] += seed;
         _jackpot = seed;
         _gameBlock = 0;
     }
 }