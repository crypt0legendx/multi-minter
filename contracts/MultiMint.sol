// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
// import "hardhat/console.sol";

interface NFT {
    // function mint(uint256 _amount) external payable;

    function setApprovalForAll(address operator, bool approved) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    // function NFT_PRICE() external view returns (uint256);

    // function MAX_SUPPLY() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    // function mintStartTime() external view returns (uint256);

    function ownerOf(uint256 tokenID) external view returns (address);

    function balanceOf(address proxy) external view returns (uint256);
}

struct WithdrawData {
    address payable cloneAddress;
    uint256[] tokenIds;
}

struct MintInfo {
    uint256 cloneIndex; 
    uint8 txPerClone;
    uint8 mintPerCall;
    uint256 nftPrice; 
    address  saleAddress; 
    bytes datacall;
    bool deployed;
}

struct MintParams {
    address saleAddress;
    uint256 nftPrice;
    uint256 maxSupply;

    uint256 clonesAmount;
    uint8 txPerClone;
    uint8 mintPerCall;
    bytes datacall;
}

struct MintDiffInfo {
    uint256 cloneIndex;
    uint8 txPerClone; 
    uint8 mintPerCall; 
    uint256 nftPrice; 
    address saleAddress; 
    bytes[] datacall;
}

struct MintDiffParams {
    address saleAddress;
    uint256 nftPrice;
    uint256 maxSupply;
    uint256 clonesAmount;
    uint8 txPerClone;
    uint8 mintPerCall;
    bytes[] datacall;
}

contract MultiMinter is Ownable {
    address payable[] public clones;

    bool initialized;
    address public _owner;

    constructor(
    ) {
        _owner = msg.sender;
    }

    function newClone() internal returns (address payable result) {
        bytes20 targetBytes = bytes20(address(this));

        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone, 0x14), targetBytes)
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            result := create(0, clone, 0x37)
        }

        return result;
    }

    function setOwner(address owner) external {
        require(!initialized, "already set");
        _owner = owner;
        initialized = true;
    }

    function clonesCreate(uint256 quantity) public {
        for (uint256 i; i < quantity; i++) {
            address payable clone = newClone();
            clones.push(clone);
            // clone.transfer(nftPrice);
            MultiMinter(clone).setOwner(address(this));
        }
    }

    function clonesDeposit(
        uint256 amount, 
        uint256 nftNumberPerClone,
        uint256 nftPrice
    )
        public
        payable
    {

        require(clones.length >= amount, "Not enough clones");
        for (uint256 i; i < amount; i++) {
            clones[i].transfer(nftPrice * nftNumberPerClone);
        }
    }

    function ethBack(address payable owner) public {
        require(msg.sender == _owner, "Not owner");
        owner.transfer(address(this).balance);
    }

    function ethBackFromClones(address payable owner) public onlyOwner {
        for (uint256 i; i < clones.length; i++) {
            MultiMinter(clones[i]).ethBack(owner);
        }
    }

    function deployedClonesMint(
        MintParams memory _mintParam
    ) public onlyOwner {
        require(_mintParam.clonesAmount <= clones.length, "Too much clones");
        uint256 totalMint = _mintParam.mintPerCall * _mintParam.txPerClone * _mintParam.clonesAmount;
        uint256 remaining = _mintParam.maxSupply - NFT(_mintParam.saleAddress).totalSupply();

        if (totalMint > remaining) {
           _mintParam.clonesAmount = remaining / (_mintParam.mintPerCall * _mintParam.txPerClone);
        }

        MintInfo memory info;

        uint256 gasPerEach = 0;
        uint256 startGas = gasleft();

        for (uint256 i; i < _mintParam.clonesAmount; i++) {
            if (gasleft() > gasPerEach) {   
                // info.cloneIndex = i;
                // info.txPerClone = _mintParam.txPerClone;
                // info.mintPerCall = _mintParam.mintPerCall;
                // info.nftPrice = _mintParam.nftPrice;
                // info.saleAddress = _mintParam.saleAddress;
                // info.datacall = _mintParam.datacall;                                    
                // info.deployed = true;
                _mintCloneInTx(i, _mintParam, true);                
                if(gasPerEach == 0){ //If gasPerEach is not set
                    gasPerEach = startGas - gasleft();
                }
            }
        }        
    }

    // function deployedClonesMintPayable(
    //     MintParams memory _mintParam
    // ) public payable {

    //     require(_mintParam.clonesAmount <= clones.length, "Too much clones");
    //     uint256 totalMint = _mintParam.mintPerCall * _mintParam.txPerClone * _mintParam.clonesAmount;
    //     uint256 remaining = _mintParam.maxSupply - NFT(_mintParam.saleAddress).totalSupply();

    //     if (totalMint > remaining) {
    //        _mintParam.clonesAmount = remaining / (_mintParam.mintPerCall * _mintParam.txPerClone);
    //     }

    //     MintInfo memory info;

    //     uint256 gasPerEach = 0;
    //     uint256 startGas = gasleft();

    //     for (uint256 i; i < _mintParam.clonesAmount; i++) {
    //         if (gasleft() > gasPerEach) {   
    //             clones[i].transfer(_mintParam.nftPrice * _mintParam.txPerClone * _mintParam.mintPerCall);
    //             info.cloneIndex = i;
    //             info.txPerClone = _mintParam.txPerClone;
    //             info.mintPerCall = _mintParam.mintPerCall;
    //             info.nftPrice = _mintParam.nftPrice;
    //             info.saleAddress = _mintParam.saleAddress;
    //             info.datacall = _mintParam.datacall;                                    
    //             info.deployed = true;
    //             _mintCloneInTx(info);                
    //             if(gasPerEach == 0){ //If gasPerEach is not set
    //                 gasPerEach = startGas - gasleft();
    //             }
    //         }
    //     }        
    // }

    function mintNoClones(
        address saleAddress,
        uint256 nftPrice,
        uint256 maxSupply,

        uint256 _numberOfTokens,
        uint256 _txCount,
        bytes calldata datacall
    ) public payable {
        uint256 totalMint = _numberOfTokens * _txCount;
        uint256 remaining = maxSupply - NFT(saleAddress).totalSupply();        

        if (totalMint > remaining) {
            _txCount = remaining / _numberOfTokens;
        }


        uint256 gasPerEach = 0;
        uint256 startGas = gasleft();
        

        for (uint256 i; i < _txCount; i++) {

            if (gasleft() > gasPerEach) {
                (bool success, bytes memory data) = saleAddress.call{
                    value: nftPrice * _numberOfTokens
                }(datacall);

                
                require(success, "Reverted from sale");
                if(gasPerEach == 0){ //If gasPerEach is not set
                    gasPerEach = startGas - gasleft();
                }

            }
        }
    }

    // function createClonesInTx(
    //     MintParams memory _mintParam
    // ) public payable {

    //     require(_mintParam.clonesAmount <= clones.length, "Too much clones");
    //     uint256 totalMint = _mintParam.mintPerCall * _mintParam.txPerClone * _mintParam.clonesAmount;
    //     uint256 remaining = _mintParam.maxSupply - NFT(_mintParam.saleAddress).totalSupply();

    //     if (totalMint > remaining) {
    //        _mintParam.clonesAmount = remaining / (_mintParam.mintPerCall * _mintParam.txPerClone);
    //     }

    //     MintInfo memory info;

    //     uint256 gasPerEach = 0;
    //     uint256 startGas = gasleft();

    //     for (uint256 i; i < _mintParam.clonesAmount; i++) {
    //         if (gasleft() > gasPerEach) {   
    //             info.cloneIndex = i;
    //             info.txPerClone = _mintParam.txPerClone;
    //             info.mintPerCall = _mintParam.mintPerCall;
    //             info.nftPrice = _mintParam.nftPrice;
    //             info.saleAddress = _mintParam.saleAddress;
    //             info.datacall = _mintParam.datacall;                                    
    //             info.deployed = false;
    //             _mintCloneInTx(info);                
    //             if(gasPerEach == 0){ //If gasPerEach is not set
    //                 gasPerEach = startGas - gasleft();
    //             }
    //         }
    //     }        
    // }

    function deployedClonesMintDiffData(
        MintDiffParams memory _mintParam
    ) public onlyOwner {
        require(_mintParam.clonesAmount <= clones.length, "Too much clones");
        uint256 totalMint = _mintParam.mintPerCall * _mintParam.txPerClone * _mintParam.clonesAmount;
        uint256 remaining = _mintParam.maxSupply - NFT(_mintParam.saleAddress).totalSupply();

        if (totalMint > remaining) {
            _mintParam.clonesAmount = remaining / (_mintParam.mintPerCall * _mintParam.txPerClone);
        }

        MintDiffInfo memory info;

        uint256 gasPerEach = 0;
        uint256 startGas = gasleft();

        for (uint256 i; i < _mintParam.clonesAmount; i++) {
            if (gasleft() > gasPerEach) {         
                info.cloneIndex = i;
                info.txPerClone = _mintParam.txPerClone;
                info.mintPerCall = _mintParam.mintPerCall;
                info.nftPrice = _mintParam.nftPrice;
                info.saleAddress = _mintParam.saleAddress;
                info.datacall = _mintParam.datacall;
                _mintCloneDiffInTx(info);                
                if(gasPerEach == 0){ //If gasPerEach is not set
                    gasPerEach = startGas - gasleft();
                }
            }
        }
    }

    function deployedClonesMintDiffDataPayable(
        MintDiffParams memory _mintParam
    ) public payable {

        require(_mintParam.clonesAmount <= clones.length, "Too much clones");
        uint256 totalMint = _mintParam.mintPerCall * _mintParam.txPerClone * _mintParam.clonesAmount;
        uint256 remaining = _mintParam.maxSupply - NFT(_mintParam.saleAddress).totalSupply();

        if (totalMint > remaining) {
            _mintParam.clonesAmount = remaining / (_mintParam.mintPerCall * _mintParam.txPerClone);
        }

        MintDiffInfo memory info;

        uint256 gasPerEach = 0;
        uint256 startGas = gasleft();

        for (uint256 i; i < _mintParam.clonesAmount; i++) {
            if (gasleft() > gasPerEach) {         
                clones[i].transfer(_mintParam.nftPrice * _mintParam.txPerClone * _mintParam.mintPerCall);
                info.cloneIndex = i;
                info.txPerClone = _mintParam.txPerClone;
                info.mintPerCall = _mintParam.mintPerCall;
                info.nftPrice = _mintParam.nftPrice;
                info.saleAddress = _mintParam.saleAddress;
                info.datacall = _mintParam.datacall;
                _mintCloneDiffInTx(info);                
                if(gasPerEach == 0){ //If gasPerEach is not set
                    gasPerEach = startGas - gasleft();
                }
            }
        }    
    }

    function _mintCloneDiffInTx(MintDiffInfo memory _info) private {
        for (uint256 j; j < _info.txPerClone; j++)
            MultiMinter(clones[_info.cloneIndex]).mintClone(
                _info.saleAddress,
                _info.mintPerCall,
                _info.nftPrice,
                _info.datacall[_info.cloneIndex]
            );
    }

    function _mintCloneInTx(cloneIndex, MintParams memory _info, bool deployed) private {
        
        if(deployed){
            for (uint256 j; j < _info.txPerClone; j++)            
                MultiMinter(clones[cloneIndex]).mintClone(
                    _info.saleAddress,
                    _info.mintPerCall,
                    _info.nftPrice,
                    _info.datacall
                );
                                             
        } else {
            address payable clone = newClone();
            clone.transfer(_info.nftPrice * _info.txPerClone * _info.mintPerCall);  

            for (uint256 j; j < _info.txPerClone; j++)            
                MultiMinter(clone).mintClone(
                    _info.saleAddress,
                    _info.mintPerCall,
                    _info.nftPrice,
                    _info.datacall
                );            
                MultiMinter(clone).setOwner(address(this));
        }   
    }

    // function _mintCloneInTx(MintInfo memory _info) private {
        
    //     if(_info.deployed){
    //         for (uint256 j; j < _info.txPerClone; j++)            
    //             MultiMinter(clones[_info.cloneIndex]).mintClone(
    //                 _info.saleAddress,
    //                 _info.mintPerCall,
    //                 _info.nftPrice,
    //                 _info.datacall
    //             );
                                             
    //     } else {
    //         address payable clone = newClone();
    //         clone.transfer(_info.nftPrice * _info.txPerClone * _info.mintPerCall);  

    //         for (uint256 j; j < _info.txPerClone; j++)            
    //             MultiMinter(clone).mintClone(
    //                 _info.saleAddress,
    //                 _info.mintPerCall,
    //                 _info.nftPrice,
    //                 _info.datacall
    //             );            
    //             MultiMinter(clone).setOwner(address(this));
    //     }   
    // }

    function mintClone (
        address sale,
        uint256 _mintPerClone,
        uint256 _nftPrice,
        bytes calldata datacall
    ) public {
        (bool success, bytes memory data) = sale.call{
            value: _nftPrice * _mintPerClone
        }(datacall);
        require(success, "Reverted from Sale");
    }

    function getArrayNft(
        WithdrawData[] memory withdrawData,
        address nftContract,
        address to
    ) public onlyOwner {
        for (uint256 i; i < withdrawData.length; i++) {
            MultiMinter(withdrawData[i].cloneAddress).getNft(
                withdrawData[i].tokenIds,
                nftContract,
                to
            );
        }
    }

    function getNft(
        uint256[] memory tokenIds,
        address sale,
        address to
    ) public {
        require(msg.sender == _owner, "Not owner");

        // NFT(sale).setApprovalForAll(to, true);
        for (uint256 i; i < tokenIds.length; i++) {
            NFT(sale).transferFrom(address(this), to, tokenIds[i]);
        }
    }

    receive() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        // return this.onERC721Received.selector;
        return 0x150b7a02;
    }
}
