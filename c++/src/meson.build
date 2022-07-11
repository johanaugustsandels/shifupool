coresrc=[
  './core/api.cpp',
  './core/block.cpp',
  './core/config.cpp',
  './core/crypto.cpp',
  # './core/header_chain.cpp',
  './core/helpers.cpp',
  # './core/logger.cpp',
  './core/merkle_tree.cpp',
  './core/transaction.cpp',
  './core/user.cpp',
  './external/bigint/bigint.cpp',
  './external/murmurhash3/MurmurHash3.cpp',
  './external/ed25519/fe.c',
  './external/ed25519/ge.c',
  './external/ed25519/sc.c',
  './external/ed25519/seed.c',
  './external/ed25519/sign.c',
  './external/ed25519/sha512.c',
  './external/ed25519/verify.c',
  './external/ed25519/keypair.c',
  './external/ed25519/add_scalar.c',
  './external/ed25519/key_exchange.c',
  './external/sha256/sha2.cpp',
  ]
thread_dep = dependency('threads')
openssl = subproject('openssl')
libcrypto_dep = openssl.get_variable('libcrypto_dep')

miner = executable('miningproblem', [coresrc,'./miningproblem/main.cpp'],
  dependencies: [thread_dep, libcrypto_dep],
  install : false)


