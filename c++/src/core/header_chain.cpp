#include "header_chain.hpp"
#include "api.hpp"
#include "block.hpp"
#include <iostream>
#include <thread>
using namespace std;

#define MAX_HASH_RETENTION 1000

void chain_sync(HeaderChain& chain) {
    while(true) {
        chain.load();
        std::this_thread::sleep_for(std::chrono::seconds(10));
    }
}


HeaderChain::HeaderChain(string host) {
    this->host = host;
    this->failed = false;
    this->offset = 0;
    this->totalWork = 0;
    this->chainLength = 0;
    this->syncThread.push_back(std::thread(chain_sync, ref(*this)));

    this->checkPoints.insert(std::pair<uint64_t, SHA256Hash>(2, stringToSHA256("0840EF092D16B7D2D31B6F8CBB855ACF36D73F5778A430B0CEDB93A6E33AF750")));
}

SHA256Hash HeaderChain::getHash(uint64_t blockId) {
    if (blockId >= this->blockHashes.size()) return NULL_SHA256_HASH;
    return this->blockHashes[blockId - 1];
}

void HeaderChain::reset() {
    this->failed = false;
    this->offset = 0;
    this->totalWork = 0;
    this->chainLength = 0;
    this->blockHashes.clear();
}

bool HeaderChain::valid() {
    return !this->failed && this->totalWork > 0;
}

string HeaderChain::getHost() {
    return this->host;
}

Bigint HeaderChain::getTotalWork() {
    if (this->failed) return 0;
    return this->totalWork;
}
uint64_t HeaderChain::getChainLength() {
    if (this->failed) return 0;
    return this->chainLength;
}

void HeaderChain::load() {
    uint64_t targetBlockCount;
    try {
        targetBlockCount = getCurrentBlockCount(this->host);
    } catch (...) {
        this->failed = true;
        return;
    }
    
    SHA256Hash lastHash = NULL_SHA256_HASH;
    if (this->blockHashes.size() > 0) {
        lastHash = this->blockHashes.back();
    }
    uint64_t numBlocks = this->blockHashes.size();
    uint64_t startBlocks = numBlocks;
    Bigint totalWork = this->totalWork;
    // download any remaining blocks in batches
    for(int i = numBlocks + 1; i <= targetBlockCount; i+=BLOCK_HEADERS_PER_FETCH) {
        try {
            int end = min(targetBlockCount, (uint64_t) i + BLOCK_HEADERS_PER_FETCH - 1);
            bool failure = false;
            vector<SHA256Hash>& hashes = this->blockHashes;
            vector<BlockHeader> blockHeaders;
            readRawHeaders(this->host, i, end, blockHeaders);
            for (auto& b : blockHeaders) {
                vector<Transaction> empty;
                Block block(b, empty);
                uint64_t curr = i;
                if (this->checkPoints.find(curr) != this->checkPoints.end()) {
                    // check the checkpoint hash:
                    if (block.getHash() != this->checkPoints[curr]) {
                        // Logger::logStatus("Checkpoint hash failed for block: " + to_string(curr));
                        failure = true;
                        break;
                    } 
                }
                if (!block.verifyNonce()) {
                    failure = true;
                    break;
                };
                if (block.getLastBlockHash() != lastHash) {
                    failure = true;
                    break;
                }
                lastHash = block.getHash();
                hashes.push_back(lastHash);
                totalWork = addWork(totalWork, block.getDifficulty());
                numBlocks++;
            }
            if (failure) {
                // Logger::logStatus("header chain sync failed host=" + this->host);
                this->failed = true;
                this->reset();
                return;
            }
        } catch (std::exception& e) {
            this->failed = true;
            this->reset();
            return;
        } catch (...) {
            this->failed = true;
            this->reset();
            return;
        }
    }
    this->chainLength = numBlocks;
    this->totalWork = totalWork;
    this->failed = false;
    if (numBlocks != startBlocks) {
        // Logger::logStatus("Chain for " + this->host + " updated to length=" + to_string(this->chainLength) + " total_work=" + to_string(this->totalWork));
    }
}


