// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ICardRegistry} from "./interfaces/ICardRegistry.sol";
import {IFeeModule} from "./interfaces/IFeeModule.sol";
import {BattleLib} from "./libraries/BattleLib.sol";
import {CommitLib} from "./libraries/CommitLib.sol";
import {Errors} from "./libraries/Errors.sol";
import {Types} from "./libraries/Types.sol";

contract DuelGame is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable stakeToken;
    ICardRegistry public immutable cardRegistry;
    uint64 public immutable revealTimeout;

    IFeeModule public feeModule; // address(0) = disabled

    uint256 public nextMatchId = 1;

    struct MatchData {
        Types.MatchConfig config;
        Types.MatchState state;
        address creator;
        address opponent;
        bytes32 commitCreator;
        bytes32 commitOpponent;
        bool revealedCreator;
        bool revealedOpponent;
        uint64 revealDeadline;
        uint256[9] lineupCreator;
        uint256[9] lineupOpponent;
    }

    mapping(uint256 => MatchData) private _matches;
    int8[6][6] private _advantage; // attackerElement -> defenderElement => 1 strong, -1 weak, 0 neutral

    event ChallengeCreated(uint256 indexed matchId, address indexed creator, bytes32 commitHash, Types.MatchConfig config);
    event ChallengeAccepted(uint256 indexed matchId, address indexed opponent, bytes32 commitHash);
    event Revealed(uint256 indexed matchId, address indexed player);
    event MatchResolved(uint256 indexed matchId, address indexed winner, uint8 winsCreator, uint8 winsOpponent, uint8 draws, uint256 pot);
    event ChallengeCancelled(uint256 indexed matchId);
    event ForfeitClaimed(uint256 indexed matchId, address indexed winner, uint256 pot);
    event ElementAdvantageSet(uint8 indexed attacker, uint8 indexed defender, int8 outcome);
    event FeeModuleSet(address indexed feeModule);
    event FeePaid(uint256 indexed matchId, address indexed treasury, uint256 fee);

    constructor(
        IERC20 stakeToken_,
        ICardRegistry cardRegistry_,
        address initialOwner,
        uint64 revealTimeout_
    ) Ownable(initialOwner) {
        if (address(stakeToken_) == address(0)) revert Errors.ZeroAddress();
        if (address(cardRegistry_) == address(0)) revert Errors.ZeroAddress();
        if (revealTimeout_ == 0) revert Errors.InvalidRevealTimeout(revealTimeout_);

        stakeToken = stakeToken_;
        cardRegistry = cardRegistry_;
        revealTimeout = revealTimeout_;

        _setDefaultAdvantageTable();
    }

    function setFeeModule(address newFeeModule) external onlyOwner {
        if (newFeeModule == address(0)) {
            feeModule = IFeeModule(address(0));
            emit FeeModuleSet(address(0));
            return;
        }

        try IFeeModule(newFeeModule).treasury() returns (address t) {
            if (t == address(0)) revert Errors.InvalidTreasury(t);
        } catch {
            revert Errors.InvalidFeeModule(newFeeModule);
        }

        try IFeeModule(newFeeModule).feeBps() returns (uint16 bps) {
            try IFeeModule(newFeeModule).maxFeeBps() returns (uint16 maxBps) {
                if (bps > maxBps) revert Errors.InvalidFeeBps(bps);
            } catch {
                revert Errors.InvalidFeeModule(newFeeModule);
            }
        } catch {
            revert Errors.InvalidFeeModule(newFeeModule);
        }

        feeModule = IFeeModule(newFeeModule);
        emit FeeModuleSet(newFeeModule);
    }

    function getMatchInfo(uint256 matchId)
        external
        view
        returns (
            Types.MatchConfig memory config,
            Types.MatchState state,
            address creator,
            address opponent,
            bool revealedCreator,
            bool revealedOpponent,
            uint64 revealDeadline
        )
    {
        MatchData storage m = _matches[matchId];
        if (m.state == Types.MatchState.None) revert Errors.MatchNotFound(matchId);
        return (m.config, m.state, m.creator, m.opponent, m.revealedCreator, m.revealedOpponent, m.revealDeadline);
    }

    function elementOutcome(uint8 attackerElement, uint8 defenderElement) external view returns (int8) {
        if (attackerElement >= 6 || defenderElement >= 6) return 0;
        return _advantage[attackerElement][defenderElement];
    }

    function setElementAdvantage(uint8 attackerElement, uint8 defenderElement, int8 outcome) external onlyOwner {
        if (attackerElement >= 6 || defenderElement >= 6) revert Errors.InvalidElement(attackerElement >= 6 ? attackerElement : defenderElement);
        if (outcome < -1 || outcome > 1) revert Errors.InvalidCardStats();
        _advantage[attackerElement][defenderElement] = outcome;
        emit ElementAdvantageSet(attackerElement, defenderElement, outcome);
    }

    function createChallenge(Types.MatchConfig calldata config, bytes32 commitHash) external nonReentrant returns (uint256 matchId) {
        _validateConfig(config);
        if (commitHash == bytes32(0)) revert Errors.InvalidCommit();

        matchId = nextMatchId++;
        MatchData storage m = _matches[matchId];

        m.config = config;
        m.state = Types.MatchState.Open;
        m.creator = msg.sender;
        m.commitCreator = commitHash;

        stakeToken.safeTransferFrom(msg.sender, address(this), uint256(config.stake));

        emit ChallengeCreated(matchId, msg.sender, commitHash, config);
    }

    function acceptChallenge(uint256 matchId, bytes32 commitHash) external nonReentrant {
        MatchData storage m = _matches[matchId];
        if (m.state != Types.MatchState.Open) revert Errors.InvalidState(matchId);
        if (commitHash == bytes32(0)) revert Errors.InvalidCommit();
        if (msg.sender == m.creator) revert Errors.SelfMatch();
        if (m.opponent != address(0)) revert Errors.InvalidState(matchId);

        m.opponent = msg.sender;
        m.commitOpponent = commitHash;
        m.state = Types.MatchState.WaitingReveal;
        m.revealDeadline = uint64(block.timestamp) + revealTimeout;

        stakeToken.safeTransferFrom(msg.sender, address(this), uint256(m.config.stake));

        emit ChallengeAccepted(matchId, msg.sender, commitHash);
    }

    function cancelUnaccepted(uint256 matchId) external nonReentrant {
        MatchData storage m = _matches[matchId];
        if (m.state != Types.MatchState.Open) revert Errors.InvalidState(matchId);
        if (msg.sender != m.creator) revert Errors.NotPlayer(matchId);

        m.state = Types.MatchState.Cancelled;
        stakeToken.safeTransfer(m.creator, uint256(m.config.stake));

        emit ChallengeCancelled(matchId);
    }

    function reveal(uint256 matchId, uint256[] calldata lineup, bytes32 salt) external nonReentrant {
        MatchData storage m = _matches[matchId];
        if (m.state != Types.MatchState.WaitingReveal) revert Errors.InvalidState(matchId);
        if (block.timestamp > m.revealDeadline) revert Errors.RevealDeadlinePassed(matchId, m.revealDeadline);

        bool isCreator = msg.sender == m.creator;
        bool isOpponent = msg.sender == m.opponent;
        if (!isCreator && !isOpponent) revert Errors.NotPlayer(matchId);

        if (isCreator) {
            if (m.revealedCreator) revert Errors.AlreadyRevealed();
            if (CommitLib.computeCommit(matchId, msg.sender, lineup, salt) != m.commitCreator) revert Errors.InvalidReveal();
            _validateAndStoreLineup(m, lineup, true);
            m.revealedCreator = true;
        } else {
            if (m.revealedOpponent) revert Errors.AlreadyRevealed();
            if (CommitLib.computeCommit(matchId, msg.sender, lineup, salt) != m.commitOpponent) revert Errors.InvalidReveal();
            _validateAndStoreLineup(m, lineup, false);
            m.revealedOpponent = true;
        }

        emit Revealed(matchId, msg.sender);

        if (m.revealedCreator && m.revealedOpponent) {
            _resolveAndPayout(matchId, m);
        }
    }

    function claimForfeit(uint256 matchId) external nonReentrant {
        MatchData storage m = _matches[matchId];
        if (m.state != Types.MatchState.WaitingReveal) revert Errors.InvalidState(matchId);
        if (block.timestamp <= m.revealDeadline) revert Errors.RevealDeadlineNotPassed(matchId, m.revealDeadline);

        uint256 pot = uint256(m.config.stake) * 2;

        m.state = Types.MatchState.Resolved;

        if (m.revealedCreator && !m.revealedOpponent) {
            _payoutWinner(matchId, m.creator, pot);
            emit ForfeitClaimed(matchId, m.creator, pot);
            return;
        }

        if (!m.revealedCreator && m.revealedOpponent) {
            _payoutWinner(matchId, m.opponent, pot);
            emit ForfeitClaimed(matchId, m.opponent, pot);
            return;
        }

        stakeToken.safeTransfer(m.creator, uint256(m.config.stake));
        stakeToken.safeTransfer(m.opponent, uint256(m.config.stake));
        emit ForfeitClaimed(matchId, address(0), pot);
    }

    function _validateConfig(Types.MatchConfig calldata config) private pure {
        if (config.stake == 0) revert Errors.ZeroStake();
        if (config.rounds != 3 && config.rounds != 6 && config.rounds != 9) revert Errors.InvalidRounds(config.rounds);
        if (config.elementalMultiplierBps < 10_000 || config.elementalMultiplierBps > 20_000) {
            revert Errors.InvalidMultiplier(config.elementalMultiplierBps);
        }
    }

    function _validateAndStoreLineup(MatchData storage m, uint256[] calldata lineup, bool forCreator) private {
        uint8 rounds = m.config.rounds;
        if (lineup.length != rounds) revert Errors.InvalidLineupLength(rounds, lineup.length);

        for (uint256 i = 0; i < rounds; i++) {
            uint256 cardId = lineup[i];
            if (cardId == 0) revert Errors.ZeroCardId();
            if (!cardRegistry.cardExists(cardId)) revert Errors.UnknownCardId(cardId);
            for (uint256 j = 0; j < i; j++) {
                if (lineup[j] == cardId) revert Errors.DuplicateCardId(cardId);
            }

            if (forCreator) {
                m.lineupCreator[i] = cardId;
            } else {
                m.lineupOpponent[i] = cardId;
            }
        }
    }

    function _resolveAndPayout(uint256 matchId, MatchData storage m) private {
        if (m.state == Types.MatchState.Resolved) revert Errors.AlreadyResolved(matchId);
        m.state = Types.MatchState.Resolved;

        Types.MatchConfig memory cfg = m.config;
        uint8 rounds = cfg.rounds;
        uint8 winsCreator;
        uint8 winsOpponent;
        uint8 draws;

        for (uint8 i = 0; i < rounds; i++) {
            ICardRegistry.CardStats memory a = cardRegistry.getCardStats(m.lineupCreator[i]);
            ICardRegistry.CardStats memory b = cardRegistry.getCardStats(m.lineupOpponent[i]);

            int8 roundWinner = BattleLib.roundWinner(
                a,
                b,
                BattleLib.attributeForRound(i),
                _elementalOutcome(a.element, b.element),
                cfg
            );

            if (roundWinner > 0) winsCreator++;
            else if (roundWinner < 0) winsOpponent++;
            else draws++;
        }

        uint256 stake = uint256(cfg.stake);
        uint256 pot = stake * 2;

        address winner = address(0);
        if (winsCreator > winsOpponent) {
            winner = m.creator;
            _payoutWinner(matchId, winner, pot);
        } else if (winsOpponent > winsCreator) {
            winner = m.opponent;
            _payoutWinner(matchId, winner, pot);
        } else {
            stakeToken.safeTransfer(m.creator, stake);
            stakeToken.safeTransfer(m.opponent, stake);
        }

        emit MatchResolved(matchId, winner, winsCreator, winsOpponent, draws, pot);
    }

    function _elementalOutcome(uint8 elementA, uint8 elementB) private view returns (int8) {
        if (elementA >= 6 || elementB >= 6) return 0;
        return _advantage[elementA][elementB];
    }

    function _payoutWinner(uint256 matchId, address winner, uint256 pot) private {
        IFeeModule module = feeModule;
        if (address(module) == address(0)) {
            stakeToken.safeTransfer(winner, pot);
            return;
        }

        (uint256 fee, uint256 payout) = module.computeFee(pot);
        if (fee != 0) {
            address treasury = module.treasury();
            if (treasury == address(0)) revert Errors.InvalidTreasury(treasury);
            stakeToken.safeTransfer(treasury, fee);
            emit FeePaid(matchId, treasury, fee);
        }

        stakeToken.safeTransfer(winner, payout);
    }

    function _setDefaultAdvantageTable() private {
        _setPairStrongWeak(uint8(Types.Element.Fire), uint8(Types.Element.Grass));
        _setPairStrongWeak(uint8(Types.Element.Fire), uint8(Types.Element.Ice));
        _setPairStrongWeak(uint8(Types.Element.Water), uint8(Types.Element.Fire));
        _setPairStrongWeak(uint8(Types.Element.Water), uint8(Types.Element.Rock));
        _setPairStrongWeak(uint8(Types.Element.Grass), uint8(Types.Element.Water));
        _setPairStrongWeak(uint8(Types.Element.Grass), uint8(Types.Element.Rock));
        _setPairStrongWeak(uint8(Types.Element.Rock), uint8(Types.Element.Fire));
        _setPairStrongWeak(uint8(Types.Element.Rock), uint8(Types.Element.Electric));
        _setPairStrongWeak(uint8(Types.Element.Electric), uint8(Types.Element.Water));
        _setPairStrongWeak(uint8(Types.Element.Electric), uint8(Types.Element.Ice));
        _setPairStrongWeak(uint8(Types.Element.Ice), uint8(Types.Element.Grass));
        _setPairStrongWeak(uint8(Types.Element.Ice), uint8(Types.Element.Electric));
    }

    function _setPairStrongWeak(uint8 strong, uint8 weak) private {
        _advantage[strong][weak] = 1;
        _advantage[weak][strong] = -1;
        emit ElementAdvantageSet(strong, weak, 1);
        emit ElementAdvantageSet(weak, strong, -1);
    }
}
