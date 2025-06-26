// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract CourseBadge is ERC1155, ERC1155Supply, Pausable, AccessControl {
    // Role definitions.
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Token ID ranges untuk organization.
    uint256 public constant CERTIFICATE_BASE = 1000;
    uint256 public constant EVENT_BADGE_BASE = 2000;
    uint256 public constant ACHIEVEMENT_BASE = 3000;
    uint256 public constant WORKSHOP_BASE = 4000;

    // Token metadata structure.
    struct TokenInfo {
        string name;
        string category;
        uint256 maxSupply;
        bool isTransferable;
        uint256 validUntil; // 0 = no expiry
        address issuer;
    }

    // Mappings.
    mapping(uint256 => TokenInfo) public tokenInfo;
    mapping(uint256 => string) private _tokenURIs;
    mapping(address => uint256[]) public studentBadges;
    mapping(uint256 => mapping(address => uint256)) public earnedAt;
    mapping(uint256 => uint256) private _rarityToMaxSupply;

    // Counter for generate unique IDs.
    uint256 private _certificateCounter;
    uint256 private _eventCounter;
    uint256 private _achievementCounter;
    uint256 private _workshopCounter;

    constructor() ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(URI_SETTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        _rarityToMaxSupply[1] = 1000; // Common
        _rarityToMaxSupply[2] = 100; // Rare
        _rarityToMaxSupply[3] = 10; // Legendary
    }

    /**
     * @dev Pause all transfers
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Override transfer to check transferability and pause.
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) whenNotPaused {
        // Check transferability for each token.
        for (uint256 i = 0; i < ids.length; i++) {
            if (from != address(0) && to != address(0)) {
                require(
                    tokenInfo[ids[i]].isTransferable,
                    "Token not transferable"
                );
            }
        }

        super._update(from, to, ids, values);
    }

    /**
     * @dev Override to return custom URI per token
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        return _tokenURIs[tokenId];
    }

    /**
     * @dev Check interface support
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Create new certificate type.
     * Use case: New lecture or program.
     */
    function createCertificateType(
        string memory _name,
        uint256 _maxSupply,
        string memory _uri
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = CERTIFICATE_BASE + _certificateCounter++;
        tokenInfo[tokenId] = TokenInfo({
            name: _name,
            category: "Certificate",
            maxSupply: _maxSupply,
            isTransferable: true,
            validUntil: 0,
            issuer: msg.sender
        });
        _tokenURIs[tokenId] = _uri;
        return tokenId;
    }

    /**
     * @dev Issue certificate to student.
     * Use case: Student complete the lecture or program.
     */
    function issueCertificate(
        address _student,
        uint256 _certificateType,
        string memory _additionalData
    ) public onlyRole(MINTER_ROLE) {
        require(exists(_certificateType), "Certificate does not exists.");
        require(
            totalSupply(_certificateType) <=
                tokenInfo[_certificateType].maxSupply,
            "Certificate max supply exceeded."
        );

        _mint(_student, _certificateType, 1, bytes(_additionalData));
        earnedAt[_certificateType][_student] = block.timestamp;
        studentBadges[_student].push(_certificateType);
    }

    // MARK: TODO
    /**
     * @dev Batch mint event badges.
     * Use case: Attendance badges for event's participants.
     */
    function mintaEventBadges(
        address[] memory _attendees,
        uint256 _eventId,
        uint256 _amount
    ) public onlyRole(MINTER_ROLE) {
        // TODO: Batch mint to multiple addresses
        // Use loop to mint to each attendee
        // Record participation
    }

    /**
     * @dev Set metadata URI for token.
     */
    function setTokenURI(uint256 _tokenId, string memory _newURI)
        public
        onlyRole(URI_SETTER_ROLE)
    {
        _tokenURIs[_tokenId] = _newURI;
    }

    /**
     * @dev Get all badges owned by student.
     */
    function getStudentBadges() public view returns (uint256[] memory) {
        return studentBadges[msg.sender];
    }

    /**
     * @dev Verify badge ownership by expiry check.
     */
    function verifyBadge(address _student, uint256 _tokenId)
        public
        view
        returns (bool isValid, uint256 earnedTimestamp)
    {
        return (
            balanceOf(_student, _tokenId) > 0 &&
                block.timestamp > tokenInfo[_tokenId].validUntil,
            earnedAt[_tokenId][_student]
        );
    }

    // Achievement System Functions

    /**
     * @dev Grant achievement badge.
     * Use case: Dean's list, competition winner, etc.
     */
    function grantAchievement(
        address _student,
        string memory _achievementName,
        uint256 _rarity // 1 = common, 2 = rare, 3 = legendary
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        require(_rarity >= 1 && _rarity <= 3, "Invalid rarity value.");

        uint256 achievementId = ACHIEVEMENT_BASE + _achievementCounter++;
        tokenInfo[achievementId] = TokenInfo({
            name: _achievementName,
            category: "Achievement",
            maxSupply: _rarityToMaxSupply[_rarity],
            isTransferable: false,
            validUntil: 0,
            issuer: msg.sender
        });

        _mint(_student, achievementId, 1, bytes(""));
        earnedAt[achievementId][_student] = block.timestamp;
        studentBadges[_student].push(achievementId);
        return achievementId;
    }

    // MARK: TODO
    /**
     * @dev Create workshop series with multiple sessions.
     */
    function createWorkshopSeries(
        string memory _seriesName,
        uint256 _totalSessions
    ) public onlyRole(MINTER_ROLE) returns (uint256[] memory) {
        // TODO: Create multiple related tokens
        // Return array of token IDs for each session

        // uint256[] storage ids;
        for (uint256 i = 0; i < _totalSessions; i++) {
            uint256 workshopId = WORKSHOP_BASE + _workshopCounter++;
            tokenInfo[workshopId] = TokenInfo({
                name: _seriesName,
                category: "Workshop",
                maxSupply: 100,
                isTransferable: true,
                validUntil: 0,
                issuer: msg.sender
            });

            // ids.push(workshopId);
        }
    }
}
