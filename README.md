# Repo du smart contract KOTH
## Jouer au jeu
Le but du jeu est de rester le roi de la colline pendant un certains temps (correspondant à un nombre de bloc).  
Pour devenir roi le jouer doit déposer dans le jeu le double de la cagnotte actuel. (visible avec `jackpotToFollow`).  
**Chargez ce contract sur Remix :**  `0x10A2D2346D60DEb08B41e4AB399C5E85B68d54A2` (réseau Rinkeby)  
```js
// ABI: 
[
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "owner_",
				"type": "address"
			},
			{
				"internalType": "uint256",
				"name": "numberOfBlocks_",
				"type": "uint256"
			}
		],
		"stateMutability": "payable",
		"type": "constructor"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "player",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "newJackpot",
				"type": "uint256"
			}
		],
		"name": "JackpotCalled",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "jackpot",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "newJackpot",
				"type": "uint256"
			}
		],
		"name": "JackpotIncreased",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "jackpot",
				"type": "uint256"
			}
		],
		"name": "JackpotWithdrew",
		"type": "event"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "account",
				"type": "address"
			}
		],
		"name": "balanceOf",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "blocksBeforeWin",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "currentWinner",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "followJackpot",
		"outputs": [],
		"stateMutability": "payable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "increaseJackpot",
		"outputs": [],
		"stateMutability": "payable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "jackpotToFollow",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "withdrawJackpot",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	}
]
```
Vous pouvez gagner plus ou moins en fonction des interactions que vous ferez avec le jeu : 
- si vous gagnez la cagnotte et que vous récupérer l'argent avant que la partie ne soit réinitialisée alors vous gagnez 90% de la cagnotte (au lieu de ~80%)
- si l'owner du contract décide de retirer sa part avant le gagnant de ce tour, alors la cagnotte n'est plus que de 76% de sa valeur initiale
------
Première version du smart contract:  
Déploié à [0x5631E1Ace442bE6A29cA864127E32503F2DD8495](https://rinkeby.etherscan.io/address/0x5631E1Ace442bE6A29cA864127E32503F2DD8495) sur Rinkeby  
**Détails :** Le nombre de block est fixé à 20
```js
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
```
-------
Deuxième version du contrat :  
Déploié à [0x10A2D2346D60DEb08B41e4AB399C5E85B68d54A2](https://rinkeby.etherscan.io/address/0x10A2D2346D60DEb08B41e4AB399C5E85B68d54A2) sur Rinkeby  
**Détails :** Le nombre de block est fixé au moment du déploiement et ne peut plus être changer.  
La répartition du jackpot change en fonction de l'adresse qui appelle la fonction pour mettre à jour les states. Cette fonctionnalité est implémenter pour **compenser les frais de transaction** du à la mise à jour des variables.
```js
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol";

/** 
 * @title KingOfTheHill
 * @author Raphael Pellet
 * @custom:rules The owner initiate an amount, then gamers have to pay the double of the amount and wait 20 block to win.
 * @notice The owner must initiate the jackpot at 1 finney or more (constructor)
 * In this version:
 *  - the number of block is set at the deployment.
 *  - a new splitting of the jackpot depends on who call the function _gameOver():
 *      New jackpot (seed) / Owner gain / Jackpot earned
 *      - Owner (by increaseJackpot() or withdrawJackpot()): 12/12/76
 *      - Winner (by withdrawJackpot()): 5/5/90
 *      - Player (by followJackpot()): 8/8/84
 * */
 
 contract KingOfTheHill {
     using Address for address payable;
     
     // storage
     address private _owner;
     mapping (address => uint256) private _gamers;
     uint256 private _jackpot;
     address private _winner;
     uint256 private _gameBlock;
     uint256 private _numberOfBlocks;
     
     
     // constructor
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
        } else if (block.number >= _gameBlock + _numberOfBlocks) {
             _gameOver(msg.sender);
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
         if (block.number >= _gameBlock + _numberOfBlocks && _gameBlock != 0) {
             _gameOver(msg.sender);
         }
         require(_gameBlock == 0, "KingOfTheHill: You cannot increase the jackpot while the game is running.");
         emit JackpotIncreased(_jackpot, _jackpot+msg.value);
         _jackpot+=msg.value;
     }
     
     function withdrawJackpot() public {
         if (block.number >= _gameBlock + _numberOfBlocks && _gameBlock != 0) {
             _gameOver(msg.sender);
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
      *     In this version the jackpot to follow will not taking into account the new splitting of this latter.
      * 
      *     - balanceOf: By imput an address you can see if the player has something to claim.
      *     CAREFUL this function is not updated automatically (it must call one of the function calling _gameOver())
      * */
     function jackpotToFollow() public view returns (uint256) {
         if (block.number >= _gameBlock + _numberOfBlocks && _gameBlock != 0) {
             return (_jackpot*10)/100;
         } else {
             return _jackpot;
         }
     }
     
     function blocksBeforeWin() public view returns (uint256) {
         if (block.number >= _gameBlock + _numberOfBlocks) {
             return 0;
         }else{
             return (_gameBlock + _numberOfBlocks) - block.number;
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
      * 
      * In this version a switch case is set here for the new splitting of the jackpot.
      * */
     
     function _gameOver(address caller) private {
         uint256 amount;
         if (caller == _owner) {
             amount = 10;
         } else if (caller == _winner){
             amount = 5;
         } else {
             amount = 8;
         }
         uint256 seed = (_jackpot*amount)/100;
         _gamers[_winner] += _jackpot-(seed*2);
         _gamers[_owner] += seed;
         _jackpot = seed;
         _gameBlock = 0;
     }
 }
```
-----
Troisième version du contrat :  
```js
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
```
----
Nouvelle fonctionnalité à mettre: une réserve récolter pour augmenter le pots du prochain game. Récolter sur le splitting du jackpot (fait par le _owner), dans un cas où le jackpot serait trop gros dès le début.  