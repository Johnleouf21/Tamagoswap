/// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

//@author Johnleouf21

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TamagoSwap is Ownable, ERC721Holder {

	uint64 private _swapsCounter;
	uint128 private _etherLocked;
	uint128 public fee;

	mapping (uint64 => Swap) private _swaps;

	struct Swap {
		address payable initiator;
		address[] initiatorNftAddresses;
		uint256[] initiatorNftIds;
		address payable secondUser;
		address[] secondUserNftAddresses;
		uint256[] secondUserNftIds;
		uint128 initiatorEtherValue;
		uint128 secondUserEtherValue;
	}

	event SwapExecuted(address indexed from, address indexed to, uint64 indexed swapId);
	event SwapCanceled(address indexed canceledBy, uint64 indexed swapId);
	event SwapProposed(
		address indexed from,
		address indexed to,
		uint64 indexed swapId,
		uint128 etherValue,
		address[] nftAddresses,
		uint256[] nftIds
	);
	event SwapInitiated(
		address indexed from,
		address indexed to,
		uint64 indexed swapId,
		uint128 etherValue,
		address[] nftAddresses,
		uint256[] nftIds
	);
	event AppFeeChanged(
		uint128 fee
	);

	modifier isApproved(address _tokenContract, uint256 _tokenId) {
        // add Approval
        require(
            IERC721(_tokenContract).getApproved(_tokenId) == address(this),
            "!approved"
        );
        _;
    }

	modifier onlyInitiator(uint64 swapId) {
		require(msg.sender == _swaps[swapId].initiator,
			"TamagoSwap: caller is not swap initiator");
		_;
	}

	modifier requireSameLength(address[] memory nftAddresses, uint256[] memory nftIds) {
		require(nftAddresses.length == nftIds.length, "TamagoSwap: NFT and ID arrays have to be same length");
		_;
	}

	modifier chargeAppFee() {
		require(msg.value >= fee, "TamagoSwap: Sent ETH amount needs to be more or equal application fee");
		_;
	}

	constructor(uint128 initalAppFee, address contractOwnerAddress) {
		fee = initalAppFee;
		super.transferOwnership(contractOwnerAddress);
	}

	function setAppFee(uint128 newFee) external onlyOwner {
		fee = newFee;
		emit AppFeeChanged(newFee);
	}

	/**
	* @dev First user proposes a swap to the second user with the NFTs that he deposits and wants to trade.
	*      Proposed NFTs are transfered to the TamagoSwap contract and
	*      kept there until the swap is accepted or canceled/rejected.
	*
	* @param secondUser address of the user that the first user wants to trade NFTs with
	* @param nftAddresses array of NFT addressed that want to be traded
	* @param nftIds array of IDs belonging to NFTs that want to be traded
	*/
	function proposeSwap(
		address secondUser,
		address[] memory nftAddresses,
		uint256[] memory nftIds
	) external payable chargeAppFee requireSameLength(nftAddresses, nftIds) {
		_swapsCounter += 1;

		safeMultipleTransfersFrom(
			msg.sender,
			address(this),
			nftAddresses,
			nftIds
		);

		Swap storage swap = _swaps[_swapsCounter];
		swap.initiator = payable(msg.sender);
		swap.initiatorNftAddresses = nftAddresses;
		swap.initiatorNftIds = nftIds;

		uint128 _fee = fee;

		if (msg.value > _fee) {
			swap.initiatorEtherValue = uint128(msg.value) - _fee;
			_etherLocked += swap.initiatorEtherValue;
		}
		swap.secondUser = payable(secondUser);

		emit SwapProposed(
			msg.sender,
			secondUser,
			_swapsCounter,
			swap.initiatorEtherValue,
			nftAddresses,
			nftIds
		);
	}

	/**
	* @dev Second user accepts the swap (with proposed NFTs) from swap initiator and
	*      deposits his NFTs into the TamagoSwap contract.
	*      Callable only by second user that is invited by swap initiator.
	*
	* @param swapId ID of the swap that the second user is invited to participate in
	* @param nftAddresses array of NFT addressed that want to be traded
	* @param nftIds array of IDs belonging to NFTs that want to be traded
	*/
	function initiateSwap(
		uint64 swapId,
		address[] memory nftAddresses,
		uint256[] memory nftIds
	) external payable chargeAppFee requireSameLength(nftAddresses, nftIds) {
		require(_swaps[swapId].secondUser == msg.sender, "TamagoSwap: caller is not swap participator");
		require(
			_swaps[swapId].secondUserEtherValue == 0 &&
			( _swaps[swapId].secondUserNftAddresses.length == 0 &&
			_swaps[swapId].secondUserNftIds.length == 0), "TamagoSwap: swap already initiated"
		);

		safeMultipleTransfersFrom(
			msg.sender,
			address(this),
			nftAddresses,
			nftIds
		);

		_swaps[swapId].secondUserNftAddresses = nftAddresses;
		_swaps[swapId].secondUserNftIds = nftIds;

		uint128 _fee = fee;

		if (msg.value > _fee) {
			_swaps[swapId].secondUserEtherValue = uint128(msg.value) - _fee;
			_etherLocked += _swaps[swapId].secondUserEtherValue;
		}

		emit SwapInitiated(
			msg.sender,
			_swaps[swapId].initiator,
			swapId,
			_swaps[swapId].secondUserEtherValue,
			nftAddresses,
			nftIds
		);
	}

	/**
	* @dev Swap initiator accepts the swap (NFTs proposed by the second user).
	*      Executeds the swap - transfers NFTs from TamagoSwap to the participating users.
	*      Callable only by swap initiator.
	*
	* @param swapId ID of the swap that the initator wants to execute
	*/
	function acceptSwap(uint64 swapId) external onlyInitiator(swapId) {
		require(
			(_swaps[swapId].secondUserNftAddresses.length != 0 || _swaps[swapId].secondUserEtherValue > 0) &&
			(_swaps[swapId].initiatorNftAddresses.length != 0 || _swaps[swapId].initiatorEtherValue > 0),
			"TamagoSwap: Can't accept swap, both participants didn't add NFTs"
		);

		// transfer NFTs from escrow to initiator
		safeMultipleTransfersFrom(
			address(this),
			_swaps[swapId].initiator,
			_swaps[swapId].secondUserNftAddresses,
			_swaps[swapId].secondUserNftIds
		);

		// transfer NFTs from escrow to second user
		safeMultipleTransfersFrom(
			address(this),
			_swaps[swapId].secondUser,
			_swaps[swapId].initiatorNftAddresses,
			_swaps[swapId].initiatorNftIds
		);

		if (_swaps[swapId].initiatorEtherValue != 0) {
			_etherLocked -= _swaps[swapId].initiatorEtherValue;
			uint128 amountToTransfer = _swaps[swapId].initiatorEtherValue;
			_swaps[swapId].initiatorEtherValue = 0;
			_swaps[swapId].secondUser.transfer(amountToTransfer);
		}
		if (_swaps[swapId].secondUserEtherValue != 0) {
			_etherLocked -= _swaps[swapId].secondUserEtherValue;
			uint128 amountToTransfer = _swaps[swapId].secondUserEtherValue;
			_swaps[swapId].secondUserEtherValue = 0;
			_swaps[swapId].initiator.transfer(amountToTransfer);
		}

		emit SwapExecuted(_swaps[swapId].initiator, _swaps[swapId].secondUser, swapId);

		delete _swaps[swapId];
	}

	/**
	* @dev Returns NFTs from TamagoSwap to swap initator.
	*      Callable only if second user hasn't yet added NFTs.
	*
	* @param swapId ID of the swap that the swap participants want to cancel
	*/
	function cancelSwap(uint64 swapId) external {
		require(
			_swaps[swapId].initiator == msg.sender || _swaps[swapId].secondUser == msg.sender,
			"TamagoSwap: Can't cancel swap, must be swap participant"
		);
		// return initiator NFTs
		safeMultipleTransfersFrom(
			address(this),
			_swaps[swapId].initiator,
			_swaps[swapId].initiatorNftAddresses,
			_swaps[swapId].initiatorNftIds
		);

		if(_swaps[swapId].secondUserNftAddresses.length != 0) {
			// return second user NFTs
			safeMultipleTransfersFrom(
				address(this),
				_swaps[swapId].secondUser,
				_swaps[swapId].secondUserNftAddresses,
				_swaps[swapId].secondUserNftIds
			);
		}

		if (_swaps[swapId].initiatorEtherValue != 0) {
			_etherLocked -= _swaps[swapId].initiatorEtherValue;
			uint128 amountToTransfer = _swaps[swapId].initiatorEtherValue;
			_swaps[swapId].initiatorEtherValue = 0;
			_swaps[swapId].initiator.transfer(amountToTransfer);
		}
		if (_swaps[swapId].secondUserEtherValue != 0) {
			_etherLocked -= _swaps[swapId].secondUserEtherValue;
			uint128 amountToTransfer = _swaps[swapId].secondUserEtherValue;
			_swaps[swapId].secondUserEtherValue = 0;
			_swaps[swapId].secondUser.transfer(amountToTransfer);
		}

		emit SwapCanceled(msg.sender, swapId);

		delete _swaps[swapId];
	}

	function safeMultipleTransfersFrom(
		address from,
		address to,
		address[] memory nftAddresses,
		uint256[] memory nftIds
	) internal virtual {
		for (uint256 i=0; i < nftIds.length; i++){
			safeTransferFrom(from, to, nftAddresses[i], nftIds[i], "");
		}
	}

	function safeTransferFrom(
		address from,
		address to,
		address tokenAddress,
		uint256 tokenId,
		bytes memory _data
	) internal virtual {
			IERC721(tokenAddress).safeTransferFrom(from, to, tokenId, _data);
		} 
		
	

	function withdrawEther(address payable recipient) external onlyOwner {
		require(recipient != address(0), "SwapKiwi: transfer to the zero address");

		recipient.transfer((address(this).balance - _etherLocked));
	}
}