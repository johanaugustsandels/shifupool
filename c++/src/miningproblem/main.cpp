#include "../core/api.hpp"
#include "../core/config.hpp"
#include "../core/crypto.hpp"
#include "../core/helpers.hpp"
#include "../core/host_manager.hpp"
#include "../core/merkle_tree.hpp"
#include "../core/user.hpp"
#include "../external/http.hpp"
#include "external/httplib.hpp"

#include <atomic>
#include <chrono>
#include <iostream>
#include <mutex>
#include <set>
#include <thread>
using namespace std;

class Bench {
public:
  Bench() : start(std::chrono::steady_clock::now()){};
  ~Bench() {
    using namespace std::chrono;
    auto end = std::chrono::steady_clock::now();
    size_t micro = duration_cast<microseconds>(end - start).count();
    std::cout << "Took " << micro << " microseconds\n";
  };

private:
  std::chrono::steady_clock::time_point start;
};

Block globalBlock;
[[nodiscard]] inline size_t zeros(SHA256Hash &hash) {
  size_t i = 0;
  while (hash[i] == 0) {
    i += 1;
    if (i == 32) {
      return 256;
    }
  }
  uint8_t v = hash[i];
  i = i * 8;
  if (v > 127)
    return i;
  if (v > 63)
    return i + 1;
  if (v > 31)
    return i + 2;
  if (v > 15)
    return i + 3;
  if (v > 7)
    return i + 4;
  if (v > 3)
    return i + 5;
  if (v > 1)
    return i + 6;
  return i + 7;
}

vector<Transaction> readRawTransactions(const std::string &bytes) {
  vector<Transaction> transactions;
  const char *curr = reinterpret_cast<const char *>(bytes.data());
  int numTx = bytes.size() / TRANSACTIONINFO_BUFFER_SIZE;
  for (int i = 0; i < numTx; i++) {
    TransactionInfo t = transactionInfoFromBuffer(curr);
    transactions.push_back(Transaction(t));
    curr += TRANSACTIONINFO_BUFFER_SIZE;
  }
  return transactions;
}

void addTxsToBlock(Block &b, const vector<Transaction> &transactions) {
  for (auto t : transactions) {
    b.addTransaction(t);
  }

  MerkleTree m;
  m.setItems(b.getTransactions());
  b.setMerkleRoot(m.getRootHash());
}

Block make_work_block(PublicWalletAddress wallet, int id, int difficulty,
                      TransactionAmount miningfee, std::string lastTimestamp,
                      string lastHashStr) {
  SHA256Hash lastHash = stringToSHA256(lastHashStr);

  // create fee to our wallet:
  Transaction fee(wallet, miningfee);
  Block newBlock;

  uint64_t timestamp =
      std::max((uint64_t)std::time(0), stringToUint64(lastTimestamp) + 1);
  newBlock.setTimestamp(timestamp);
  newBlock.setId(id);
  newBlock.addTransaction(fee);

  MerkleTree m;
  m.setItems(newBlock.getTransactions());
  newBlock.setMerkleRoot(m.getRootHash());

  newBlock.setDifficulty(difficulty);
  newBlock.setLastBlockHash(lastHash);
  return newBlock;
}

int main(int, char **) {
  srand(std::time(0));

  // HTTP
  httplib::Server svr;
  svr.Get(R"(/keygen)", [](const httplib::Request &, httplib::Response &res) {
    std::pair<PublicKey, PrivateKey> pair = generateKeyPair();
    PublicKey publicKey = pair.first;
    PrivateKey privateKey = pair.second;
    // PublicWalletAddress w = walletAddressFromPublicKey(publicKey);
    json j;
    j["wallet"] = walletAddressToString(walletAddressFromPublicKey(publicKey));
    j["pubKey"] = publicKeyToString(publicKey);
    j["privKey"] = privateKeyToString(privateKey);
    res.set_content(j.dump(), "text/plain");
  });
  svr.Get(R"(/tx/(.*)/(.*)/(.*)/(.*)/(.*)/(.*))", [](const httplib::Request &r,
                                                     httplib::Response &res) {
    json j;
    j["status"] = "ok";
    try {
      PublicKey publicKey = stringToPublicKey(r.matches[1]);
      PrivateKey privateKey = stringToPrivateKey(r.matches[2]);
      PublicWalletAddress toAddress = stringToWalletAddress(r.matches[3]);
      PublicWalletAddress fromAddress = walletAddressFromPublicKey(publicKey);
      TransactionAmount amount = stringToUint64(r.matches[4]);
      TransactionAmount fee = stringToUint64(r.matches[5]);
      uint64_t nonce = stringToUint64(r.matches[6]);

      Transaction t(fromAddress, toAddress, amount, publicKey, fee, nonce);
      t.sign(publicKey, privateKey);
      j["transaction"] = t.toJson();
      res.set_content(j.dump(), "text/plain");
    } catch (...) {
      j["status"] = "CORRUPT";
      res.set_content(j.dump(), "text/plain");
    }
  });
  svr.Get(R"(/problem/(.*)/(.*)/(.*)/(.*)/(.*)/(.*))",
          [](const httplib::Request &r, httplib::Response &res) {
            json j;
            try {
              std::string walletHex = r.matches[1];
              int id = std::stoi(r.matches[2]);
              int difficulty = std::stoi(r.matches[3]);
              TransactionAmount miningfee = std::stoi(r.matches[4]);
              std::string lastTimestamp = r.matches[5];
              string lastHashStr = r.matches[6];

              PublicWalletAddress wallet{stringToWalletAddress(walletHex)};
              // Block make_work_block(PublicWalletAddress wallet, int id,int
              // difficulty, TransactionAmount miningfee,std::string
              // lastTimestamp,string lastHashStr)
              globalBlock = make_work_block(wallet, id, difficulty, miningfee,
                                            lastTimestamp, lastHashStr);

              //
              auto h = globalBlock.getHash();
              auto encoded = hexEncode((char *)h.data(), h.size());
              j["blockhashhex"] = encoded;
              res.set_content(j.dump(), "text/plain");
            } catch (...) {
              j["status"] = "CORRUPT";
              res.set_content(j.dump(), "text/plain");
            }
          });
  svr.Post(R"(/add_transactions)",
           [](const httplib::Request &r, httplib::Response &res) {
             json j;
             try {
               auto txs = readRawTransactions(r.body);
               if (txs.size() > 0) {
                 addTxsToBlock(globalBlock, txs);
               }
               auto h = globalBlock.getHash();
               auto encoded = hexEncode((char *)h.data(), h.size());
               j["blockhashhex"] = encoded;
               res.set_content(j.dump(), "text/plain");
             } catch (...) {
               j["status"] = "CORRUPT";
               res.set_content(j.dump(), "text/plain");
             }
           });
  svr.Post(R"(/pufferfish)",
           [](const httplib::Request &r, httplib::Response &res) {
             json j;
             try {

               SHA256Hash ret;
               {
                 cout << "hash\n";
                 Bench b;
                 ret = SHA256(r.body.data(), r.body.size(), true);
               }
               size_t z = zeros(ret);
               auto encoded = hexEncode((char *)ret.data(), ret.size());
               j["hash"] = encoded;
               j["zeros"] = z;
               res.set_content(j.dump(), "text/plain");
             } catch (...) {
               j["status"] = "CORRUPT";
               res.set_content(j.dump(), "text/plain");
             }
           });
  svr.Get(R"(/submit_pufferfish/(.*$))",
          [](const httplib::Request &r, httplib::Response &res) {
            cout << "submit_pufferfish" << endl;
            std::string nonce = r.matches[1];
            json j;
            if (nonce.size() != 64) {
              j["status"] = "CORRUPT";
              res.set_content(j.dump(), "text/plain");
            } else {
              auto decoded = hexDecode(nonce);
              SHA256Hash h;
              memcpy(h.data(), decoded.data(), 32);
              vector<uint8_t> bytes;
              {
                std::unique_lock<std::mutex> l(mutex);
                globalBlock.setNonce(h);
                Block &block = globalBlock;
                if (!block.verifyNonce(true)) {
                  j["status"] = "INVNONCE";
                  res.set_content(j.dump(), "text/plain");
                  return;
                }

                BlockHeader b = block.serialize();
                bytes.resize(BLOCKHEADER_BUFFER_SIZE +
                             TRANSACTIONINFO_BUFFER_SIZE * b.numTransactions);

                char *ptr = (char *)bytes.data();
                blockHeaderToBuffer(b, ptr);
                ptr += BLOCKHEADER_BUFFER_SIZE;

                for (auto t : block.getTransactions()) {
                  TransactionInfo tx = t.serialize();
                  transactionInfoToBuffer(tx, ptr);
                  ptr += TRANSACTIONINFO_BUFFER_SIZE;
                }
              }

              auto encoded = hexEncode((char *)bytes.data(), bytes.size());
              j["status"] = "ok";
              j["hexdump"] = encoded;
              res.set_content(j.dump(), "text/plain");
            }
          });
  svr.Get(R"(/submit/(.*$))",
          [](const httplib::Request &r, httplib::Response &res) {
            std::string nonce = r.matches[1];
            json j;
            if (nonce.size() != 64) {
              j["status"] = "CORRUPT";
              res.set_content(j.dump(), "text/plain");
            } else {
              auto decoded = hexDecode(nonce);
              SHA256Hash h;
              memcpy(h.data(), decoded.data(), 32);
              vector<uint8_t> bytes;
              {
                std::unique_lock<std::mutex> l(mutex);
                globalBlock.setNonce(h);
                Block &block = globalBlock;
                if (!block.verifyNonce(false)) {
                  j["status"] = "INVNONCE";
                  res.set_content(j.dump(), "text/plain");
                  return;
                }

                BlockHeader b = block.serialize();
                bytes.resize(BLOCKHEADER_BUFFER_SIZE +
                             TRANSACTIONINFO_BUFFER_SIZE * b.numTransactions);

                char *ptr = (char *)bytes.data();
                blockHeaderToBuffer(b, ptr);
                ptr += BLOCKHEADER_BUFFER_SIZE;

                for (auto t : block.getTransactions()) {
                  TransactionInfo tx = t.serialize();
                  transactionInfoToBuffer(tx, ptr);
                  ptr += TRANSACTIONINFO_BUFFER_SIZE;
                }
              }

              auto encoded = hexEncode((char *)bytes.data(), bytes.size());
              j["status"] = "ok";
              j["hexdump"] = encoded;
              res.set_content(j.dump(), "text/plain");
            }
          });
  int port = 4002;
  constexpr const char portvariable[] = "SHIFUPOOL_BACKEND_PORT";
  if (const char *env_p = std::getenv(portvariable)) {
    try {
      port = std::stoi(env_p);
    } catch (...) {
      cerr << "Please specify a valid port in the variable \""<<portvariable<<"\"."<<endl;
      return -1;
    }
  }
  cout<<"Listening on loopback port "<<port<<endl;
  svr.listen("127.0.0.1", port);
}
