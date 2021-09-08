// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/ILocker.sol";

contract Locker is ILocker, ERC1155Holder, ERC721Holder, Ownable {
    // locker contents
    mapping(uint256 => LockerContents) private _lockerContents;
    uint256 _fee = 0;

    /// @notice call to drop off your token
    /// @param unlockTokenAddress address of unlock token
    /// @param unlockTokenHash unlock token hash
    /// @param awardTokenAddress token address
    /// @param awardTokenHash token hash
    /// @param awardQty token hash
    function dropOff(
        address unlockTokenAddress,
        uint256 unlockTokenHash,
        address awardTokenAddress,
        uint256 awardTokenHash,
        uint256 awardQty
    ) external override {
        // there should be nothing where we are dropping off
        require(
            _lockerContents[unlockTokenHash].unlockTokenAddress == address(0),
            "Token already registered"
        );

        // make sure fee is paid
        require(msg.sender.balance >= _fee, "fee required.");

        // make sure we are depositing > 0 contents
        require(awardQty > 0, "Award quantity must be greater than 0");

        // require that unlock token is ERC1155 or ERC721
        bool unlockSupports1155 = IERC165(unlockTokenAddress).supportsInterface(
            type(IERC1155).interfaceId
        );
        bool unlockSupports721 = IERC165(unlockTokenAddress).supportsInterface(
            type(IERC721).interfaceId
        );
        require(
            unlockSupports1155 || unlockSupports721,
            "Unlock token must be 1155 or 721"
        );

        // require that award token is ERC1155 or ERC721 or ERC20
        bool awardSupports1155 = IERC165(awardTokenAddress).supportsInterface(
            type(IERC1155).interfaceId
        );
        bool awardSupports721 = IERC165(awardTokenAddress).supportsInterface(
            type(IERC721).interfaceId
        );
        bool awardSupports20 = IERC165(awardTokenAddress).supportsInterface(
            type(IERC20).interfaceId
        );
        require(
            awardSupports1155 || awardSupports721 || awardSupports20,
            "Award token must be 1155 or 721 or 20"
        );

        // if we are depositing ERC1155, make sure we are depositing the correct token
        if (awardSupports721) {
            // make sure we have enough balance of award token to deposit
            require(
                IERC721(awardTokenAddress).balanceOf(msg.sender) >= awardQty,
                "Award quantity must be non-zero"
            );
        }
        // if we are depositing ERC1155, make sure we are depositing the correct token
        else if (awardSupports1155) {
            // make sure we have enough balance of award token to deposit
            require(
                IERC1155(awardTokenAddress).balanceOf(
                    msg.sender,
                    awardTokenHash
                ) >= awardQty,
                "Award quantity must be non-zero"
            );
        }
        // if we are depositing ERC20, make sure we are depositing the correct token
        else if (awardSupports20) {
            // make sure we have enough balance of award token to deposit
            require(
                IERC20(awardTokenAddress).balanceOf(msg.sender) >= awardQty,
                "Award quantity must be non-zero"
            );
        }

        // store the locker contents
        _lockerContents[unlockTokenHash] = LockerContents(
            unlockTokenAddress,
            unlockTokenHash,
            awardTokenAddress,
            awardTokenHash,
            awardQty
        );

        // if we are depositing ERC1155, make sure we are depositing the correct token
        if (awardSupports721) {
            // deposit the award token into the locker
            IERC721(awardTokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                awardTokenHash,
                ""
            );
        }
        // if we are depositing ERC1155, make sure we are depositing the correct token
        else if (awardSupports1155) {
            // deposit the award token into the locker
            IERC1155(awardTokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                awardTokenHash,
                awardQty,
                ""
            );
        }
        // if we are depositing ERC20, make sure we are depositing the correct token
        else if (awardSupports20) {
            // deposit the award token into the locker
            IERC20(awardTokenAddress).transferFrom(
                msg.sender,
                address(this),
                awardQty
            );
        }

        // emit an event
        emit LockerContentsDroppedOff(
            msg.sender,
            awardTokenAddress,
            awardTokenHash,
            awardQty
        );
    }

    /// @param tokenHashKey token hash
    function contents(uint256 tokenHashKey)
        external
        view
        override
        returns (LockerContents memory _locker)
    {
        _locker = _lockerContents[tokenHashKey];
    }

    /// @notice pick up the token
    /// @param _openCode the pickup code
    /// @param receiver the receiver of the contents
    function _pickupToken(uint256 _openCode, address receiver) internal {
        // make sure we still have tokens to give
        require(_lockerContents[_openCode].awardQty > 0, "No token to pick up");

        uint256 theAwardQty = _lockerContents[_openCode].awardQty;

        // set to zero first to prevent reentrancy
        _lockerContents[_openCode].awardQty = 0;

        // require that award token is ERC1155 or ERC721 or ERC20
        bool awardSupports1155 = IERC165(_lockerContents[_openCode].awardTokenAddress).supportsInterface(
            type(IERC1155).interfaceId
        );
        bool awardSupports721 = IERC165(_lockerContents[_openCode].awardTokenAddress).supportsInterface(
            type(IERC721).interfaceId
        );
        bool awardSupports20 = IERC165(_lockerContents[_openCode].awardTokenAddress).supportsInterface(
            type(IERC20).interfaceId
        );

        // if award token is 721 then send as ERC721
        if (awardSupports721) {
            // then send the token
            IERC721(_lockerContents[_openCode].awardTokenAddress)
                .safeTransferFrom(
                    address(this),
                    receiver,
                    theAwardQty,
                    ""
                );
        } 
        // if award token is 1155 then send as ERC1155
        else if (awardSupports1155) {
            // then send the token
            IERC1155(_lockerContents[_openCode].awardTokenAddress)
                .safeTransferFrom(
                    address(this),
                    receiver,
                    _lockerContents[_openCode].awardTokenHash,
                    theAwardQty,
                    ""
                );
        } 
        // if award token is 20 then send as ERC20
        else if (awardSupports20) {
            // then send the token
            IERC20(_lockerContents[_openCode].awardTokenAddress)
                .transferFrom(
                    address(this),
                    receiver,
                    theAwardQty
                );       
        }

        // and emit an event
        emit LockerContentsPickedUp(
            receiver,
            _lockerContents[_openCode].awardTokenAddress,
            _lockerContents[_openCode].awardTokenHash,
            theAwardQty
        );
    }

    /// @notice call to pick up your erc 11555 NFT given a source erc1155 in your possession
    /// @param unlockTokenHashKey the token hash which will unlock your locker
    function pickUpTokenWithKey(uint256 unlockTokenHashKey) external override {
        // get the locker contents
        LockerContents memory _contents = _lockerContents[unlockTokenHashKey];

        // require unlock token hash matches
        require(
            _contents.unlockTokenHash == unlockTokenHashKey,
            "Unlock Token hash missmatched"
        );

        // require there be a quantity to pick up
        require(_contents.awardQty > 0, "No token to pick up");

        // require user to have unlock nft in posession
        require(
            IERC1155(_contents.unlockTokenAddress).balanceOf(
                msg.sender,
                unlockTokenHashKey
            ) > 0,
            "No unlock nft available"
        );

        // pick up the token and generate event
        _pickupToken(unlockTokenHashKey, msg.sender);
    }

    // withdraw accrued fees
    function setFee(uint256 fee) external {
        _fee = fee;
    }

    // withdraw accrued fees
    function withdraw(address _to) external {
        require(address(this).balance > 0, "No token to pick up");
        payable(_to).transfer(address(this).balance);
    }
}
