#!/bin/bash

# Prevent sensitive input from being recorded in shell history
unset HISTFILE

declare -a WORDARRAY

function read_word_file {
  words=0
  if [[ ! -f "wordlist.txt" ]]; then
    echo "Error: wordlist.txt not found."
    exit 1
  fi

  while IFS='' read -r line || [[ -n "$line" ]]; do
    ((words++))
    WORDARRAY["$words"]="$line"
  done < "wordlist.txt"
  echo "Loaded $words words."
}

function ask_for_pass {
  echo "Name of the key:"
  read -r NAME
  echo "Password: "
  read -rs PASS
  
  RAW_SALT="${NAME}_monero_salt_padding"
  SALT="${RAW_SALT:0:16}"
  unset RAW_SALT
}

function ask_for_seed_to_decrypt {
  echo "Type encrypted seed numbers (e.g. 1086-1995-1353-...):"
  read -r SEED
}

function create_salt {
  echo "Deriving key material (this will take time)..."

  PASS_ACCUMULATOR="$NAME$PASS"

  for n in {1..100}; do
    # Step A: PBKDF2 (6M iterations, 128 hex chars)
    PASS1=$(openssl kdf -keylen 64 \
      -kdfopt digest:SHA512 \
      -kdfopt pass:"$PASS_ACCUMULATOR" \
      -kdfopt salt:"$SALT" \
      -kdfopt iter:6000000 PBKDF2 | xxd -p -c 64 | tr -d '\r\n')

    # Step B: Pre-hash
    PASS1_HASH=$(echo -n "$PASS1" | sha512sum | cut -d' ' -f1 | tr -d '\r\n')

    # Step C: Argon2id (512 MB RAM per pass)
    PASS1_TRUNC="${PASS1_HASH:0:125}"
    PASS2=$(argon2 "$SALT" -id -m 19 -t 4 -p 2 -l 64 -e <<< "$PASS1_TRUNC" | cut -d'$' -f6 | tr -d '\r\n')

    # State accumulation
    PASS_ACCUMULATOR=$(echo -n "${PASS1}${PASS2}" | sha512sum | cut -d' ' -f1 | tr -d '\r\n')
    echo -n "#"
  done

  # Finalizing pass
  PASS_HEX=$(openssl kdf -keylen 64 \
    -kdfopt digest:SHA512 \
    -kdfopt pass:"$PASS_ACCUMULATOR" \
    -kdfopt salt:"$SALT" \
    -kdfopt iter:60000 PBKDF2 | xxd -p -c 64 | tr -d '\r\n')

  # Uniform Hex-to-Digit Modulo Mapping (0-9)
  PASS_FINAL=""
  for (( i=0; i<120; i++ )); do
    char="${PASS_HEX:$i:1}"
    digit=$(( 16#$char % 10 ))
    PASS_FINAL="${PASS_FINAL}${digit}"
  done

  echo ""
  echo "Key created successfully."

  # Clear intermediate secrets
  unset PASS PASS_ACCUMULATOR PASS1 PASS1_HASH PASS1_TRUNC PASS2 PASS_HEX SALT
}

function decrypt_seed {
  COUNTER1=0
  SEED_DECRYPTED_FINAL=""

  # Split input dash-separated numbers into an array instantly without subshells
  IFS='-' read -ra ENCRYPTED_NUMS <<< "$SEED"

  if [[ ${#ENCRYPTED_NUMS[@]} -ne 24 ]]; then
    echo "Warning: Expected 24 encrypted numbers, got ${#ENCRYPTED_NUMS[@]}."
  fi

  for i in {0..23}; do
    # Extract 5-digit block via native Bash slicing
    BLOCK="${PASS_FINAL:$COUNTER1:5}"
    
    # Base-10 safe integer conversion (handles leading zeros properly)
    TMPN=$((10#$BLOCK % words))

    NUM="${ENCRYPTED_NUMS[$i]}"
    WORD_INDEX=$((NUM - TMPN))

    # Single string assembly
    SEED_DECRYPTED_FINAL="$SEED_DECRYPTED_FINAL ${WORDARRAY[$WORD_INDEX]}"

    ((COUNTER1 += 5))
  done

  # Strip leading whitespace
  SEED_DECRYPTED_FINAL="${SEED_DECRYPTED_FINAL# }"

  echo "--------------------------------------------------------------------------------"
  echo "Decrypted seed: $SEED_DECRYPTED_FINAL"
  
  DECRYPTED_HASH=$(echo -n "$SEED_DECRYPTED_FINAL" | sha512sum | cut -d " " -f 1)
  echo "Decrypted SEED Hash: $DECRYPTED_HASH"
  echo "--------------------------------------------------------------------------------"

  # Wipe sensitive values from environment memory
  unset SEED PASS_FINAL SEED_DECRYPTED_FINAL DECRYPTED_HASH WORDARRAY ENCRYPTED_NUMS NAME
}

# Execution Sequence
echo "Seed decryptor with password key derivation."
read_word_file
ask_for_pass
ask_for_seed_to_decrypt
create_salt
decrypt_seed
