// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * GasPatterns.sol
 *
 * A teaching playground of gas-optimized Solidity patterns.
 *
 * Patterns:
 * 1) Use calldata for read-only external functions with large arrays/bytes
 * 2) Calldata slicing without copying (return slices via view helpers)
 * 3) Use `unchecked` for safe arithmetic when overflow is impossible
 * 4) Pack storage variables into single slots via short types and ordering
 * 5) Use immutable and constant for compile-time/storage savings
 * 6) Yul memcpy for efficient bytes copying
 * 7) Minimal loops and short-circuiting
 * 8) Compact events: index topics thoughtfully
 * 9) Bitpacking / single-slot booleans & small ints
 * 10) Gas-optimized ERC20 mint pattern (unchecked + events)
 *
 * NOTE: These are demonstration helpers — in production, combine with audits and tests.
 */

contract GasPatterns {
    /* ============================
       0. Constants & Immuntables
       ============================ */
    uint256 public constant MAX_SUPPLY = 1_000_000 ether; // compile-time constant (no storage)
    address public immutable deployer; // stored once at construction cheaper than storage set later

    constructor() {
        deployer = msg.sender;
    }

    /* ============================
       1. Calldata vs Memory
       ============================ */
    // Accepts a large array but uses calldata to avoid copy into memory
    function sumUintArrayCalldata(uint256[] calldata arr) external pure returns (uint256 sum) {
        // reading from calldata is cheaper than copying to memory
        for (uint256 i = 0; i < arr.length; ++i) {
            sum += arr[i];
        }
    }

    // If you need to operate many times on bytes, use Yul memcpy to minimize costs
    function concatTwo(bytes calldata a, bytes calldata b) external pure returns (bytes memory out) {
        // naive copying would allocate and copy; instead we allocate once and memcpy
        uint256 lenA = a.length;
        uint256 lenB = b.length;
        uint256 tot = lenA + lenB;
        out = new bytes(tot);
        assembly {
            // copy a
            let dest := add(out, 32)
            calldatacopy(dest, add(a.offset, 0), lenA)
            // copy b
            calldatacopy(add(dest, lenA), add(b.offset, 0), lenB)
            mstore(out, tot) // set length (not needed — new bytes sets it)
        }
    }

    /* ============================
       2. Calldata slicing (no copy)
       ============================ */
    // Return a view-like hash of a slice without copying entire bytes
    function keccakSlice(bytes calldata data, uint256 start, uint256 length) external pure returns (bytes32) {
        require(start + length <= data.length, "out of bounds");
        // keccak256 supports calldata directly with this form in Yul via calldata hashing
        bytes32 h;
        assembly {
            // compute pointer to calldata region and hash it
            // note: keccak256 on calldata requires copying to memory in solidity - do via calldatacopy then keccak256
            let memPtr := mload(0x40)
            calldatacopy(memPtr, add(data.offset, start), length)
            h := keccak256(memPtr, length)
        }
        return h;
    }

    /* ============================
       3. Unchecked arithmetic
       ============================ */
    // If you guarantee no overflow (e.g., bounds checked), use unchecked for +/-
    function increment(uint256 x) external pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

    /* ============================
       4. Storage packing & bitpacking
       ============================ */
    // tightly pack small variables into one slot
    struct Packed {
        uint128 a; // 16 bytes
        uint64 b;  // 8 bytes
        uint32 c;  // 4 bytes
        // total 28 bytes -> fits in one 32-byte slot
    }
    Packed public p;

    function setPacked(uint128 a_, uint64 b_, uint32 c_) external {
        p.a = a_;
        p.b = b_;
        p.c = c_;
    }

    /* Example of explicit bit-packing into one uint256 slot */
    uint256 private packedFlags; // store multiple small flags/ints

    // store two 16-bit values and a boolean (fits into 32 bits)
    function setPackedFlags(uint16 v1, uint16 v2, bool f) external {
        // clear lower 32 bits then set
        packedFlags = (packedFlags & ~uint256(0xffffffff)) | (uint256(v1) | (uint256(v2) << 16) | (f ? (1 << 31) : 0));
    }

    function getPackedFlags() external view returns (uint16 v1, uint16 v2, bool f) {
        uint256 v = packedFlags & 0xffffffff;
        v1 = uint16(v & 0xffff);
        v2 = uint16((v >> 16) & 0xffff);
        f = ((v >> 31) & 1) == 1;
    }

    /* ============================
       5. Gas-optimized event usage
       ============================ */
    // Index frequently-filtered fields and avoid indexing large text blobs
    event TransferOptimized(address indexed from, address indexed to, uint256 value);

    /* ============================
       6. Yul memcpy example (fast memory copy)
       ============================ */
    // Copies `len` bytes from src (memory) to dest (memory) using a loop of 32-byte stores
    function yulMemCopy(bytes memory src, uint256 srcOffset, uint256 destOffset, uint256 len) public pure {
        assembly {
            let srcPtr := add(add(src, 32), srcOffset)
            let destPtr := add(add(src, 32), destOffset) // using same src buffer for demonstration
            let end := add(srcPtr, len)
            for {

            } lt(srcPtr, end) {
                srcPtr := add(srcPtr, 0x20)
                destPtr := add(destPtr, 0x20)
            } {
                mstore(destPtr, mload(srcPtr))
            }
        }
    }

    /* ============================
       7. Gas-optimized ERC20 mint (demo)
       ============================ */
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    function mintOptimized(address to, uint256 amount) external {
        require(to != address(0), "zero");
        // Gas optimization: read-modify-write once, use unchecked for sum (if invariants hold)
        uint256 old = balanceOf[to];
        uint256 newBal = old + amount;
        require(totalSupply + amount <= MAX_SUPPLY, "max supply");
        balanceOf[to] = newBal;
        totalSupply += amount;
        emit TransferOptimized(address(0), to, amount);
    }

    /* ============================
       8. Minimal loop & short-circuiting
       ============================ */
    // Sum and early exit when encountering zero to save gas
    function sumUntilZero(uint256[] calldata arr) external pure returns (uint256 sum) {
        for (uint256 i = 0; i < arr.length; ++i) {
            uint256 v = arr[i];
            if (v == 0) break; // exit early
            sum += v;
        }
    }

    /* ============================
       9. No-zero-copy pattern for strings
       ============================ */
    // Return keccak of calldata string without copying whole string into memory
    function hashCalldataString(bytes calldata s) external pure returns (bytes32) {
        assembly {
            // allocate memory and copy only as needed via calldatacopy
            let ptr := mload(0x40)
            calldatacopy(ptr, add(s.offset, 0), s.length)
            let h := keccak256(ptr, s.length)
            mstore(0x00, h)
            return(0x00, 0x20)
        }
    }

    /* ============================
       10. Efficient batch transfer using calldata struct
       ============================ */
    struct Transfer {
        address to;
        uint256 amount;
    }

    // ABI-encode as bytes calldata to avoid decoding into memory structures early
    // Here we accept flattened arrays in calldata (addresses[] and amounts[]) to avoid per-element allocation
    function batchTransfer(address[] calldata tos, uint256[] calldata amounts) external {
        require(tos.length == amounts.length, "len");
        for (uint256 i = 0; i < tos.length; ++i) {
            address to = tos[i];
            uint256 amt = amounts[i];
            // transfer logic (simplified)
            balanceOf[to] += amt;
            totalSupply += amt;
            emit TransferOptimized(msg.sender, to, amt);
        }
    }

    /* ============================
       Helper: gas measurement functions (call & return gasleft)
       ============================ */
    function gasLeftBefore() external view returns (uint256) {
        return gasleft();
    }

    function gasLeftAfter() external view returns (uint256) {
        // trivial function to compare with above in tests
        return gasleft();
    }
}
