#!/bin/bash

# Prevent sensitive inputs from being recorded in shell history
unset HISTFILE

declare -A WORDMAP
declare -a WORDARRAY
declare -a SEEDARRAY

function read_word_file {
  words=0
  if [[ ! -f "wordlist.txt" ]]; then
    echo "Error: wordlist.txt not found."
    exit 1
  fi

  while IFS='' read -r line || [[ -n "$line" ]]; do
    ((words++))
    WORDARRAY["$words"]="$line"
    WORDMAP["$line"]="$words" # O(1) Reverse lookup map
  done < "wordlist.txt"
  echo "We have $words words."
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

function ask_for_seed_to_encrypt {
  echo "Type seed (only 24 first words using lower case letters):"
  read -rs SEED_TO_ENCRYPT
  echo ""

  # Generate seed verification hash
  SEED_TESTHASH=$(echo -n "$SEED_TO_ENCRYPT" | sha512sum | cut -d " " -f 1)

  # Convert string to array
  read -ra INPUT_WORDS <<< "$SEED_TO_ENCRYPT"
  
  if [[ ${#INPUT_WORDS[@]} -ne 24 ]]; then
    echo "Warning: Expected 24 words, got ${#INPUT_WORDS[@]}."
  fi

  for i in {1..24}; do
    word="${INPUT_WORDS[$((i-1))]}"
    idx="${WORDMAP[$word]}"
    
    if [[ -n "$idx" ]]; then
      SEEDARRAY["$i"]="$idx"
    else
      echo "Error: Word '$word' not found in wordlist.txt"
      exit 1
    fi
  done

  # Clear sensitive raw seed text from memory
  unset SEED_TO_ENCRYPT INPUT_WORDS
}

function create_salt {
  echo "Deriving key material..."

  PASS_ACCUMULATOR="$NAME$PASS"

  for n in {1..100}; do
    # Step A: PBKDF2
    PASS1=$(openssl kdf -keylen 64 \
      -kdfopt digest:SHA512 \
      -kdfopt pass:"$PASS_ACCUMULATOR" \
      -kdfopt salt:"$SALT" \
      -kdfopt iter:6000000 PBKDF2 | xxd -p -c 64 | tr -d '\r\n')

    # Step B: Hash check
    PASS1_HASH=$(echo -n "$PASS1" | sha512sum | cut -d' ' -f1 | tr -d '\r\n')

    # Step C: Argon2id
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

  # Clear intermediate key derivation secrets
  unset PASS PASS_ACCUMULATOR PASS1 PASS1_HASH PASS1_TRUNC PASS2 PASS_HEX SALT
}

function encrypt_seed {
  COUNTER1=0
  SEED=""

  for i in {1..24}; do
    # Native Bash slice instead of 'cut -c' subshell
    BLOCK="${PASS_FINAL:$COUNTER1:5}"
    
    # Strip leading zeros safely via base-10 arithmetic
    TMPN=$((10#$BLOCK % words))
    
    TMPN2=${SEEDARRAY[$i]}
    TMPN=$((TMPN + TMPN2))

    if [[ -z "$SEED" ]]; then
      SEED="$TMPN"
    else
      SEED="$SEED-$TMPN"
    fi

    ((COUNTER1 += 5))
  done

  # Clear internal array state
  unset SEEDARRAY
}

function check_decryption {
  echo "Checking decryption..."
  COUNTER1=0
  SEED_DECRYPTED_FINAL=""

  IFS='-' read -ra ENCRYPTED_NUMS <<< "$SEED"

  for i in {0..23}; do
    BLOCK="${PASS_FINAL:$COUNTER1:5}"
    TMPN=$((10#$BLOCK % words))
    
    SEED_DECRYPTED="${ENCRYPTED_NUMS[$i]}"
    SEED_DECRYPTED=$((SEED_DECRYPTED - TMPN))

    # Single string concatenation
    SEED_DECRYPTED_FINAL="$SEED_DECRYPTED_FINAL ${WORDARRAY[$SEED_DECRYPTED]}"

    ((COUNTER1 += 5))
  done

  # Strip leading whitespace
  SEED_DECRYPTED_FINAL="${SEED_DECRYPTED_FINAL# }"

  echo -n "Decrypted seed prefix: "
  echo "${SEED_DECRYPTED_FINAL:0:20}"
  echo "Original SEED Hash:    $SEED_TESTHASH"
  
  DECRYPTED_HASH=$(echo -n "$SEED_DECRYPTED_FINAL" | sha512sum | cut -d " " -f 1)
  echo "Decrypted SEED Hash:   $DECRYPTED_HASH"

  if [[ "$SEED_TESTHASH" == "$DECRYPTED_HASH" ]]; then
    echo "Decryption check: MATCH SUCCESSFUL"
  else
    echo "Decryption check: FAILED"
  fi

  # Final cleanup of sensitive values in memory
  unset PASS_FINAL SEED_DECRYPTED_FINAL DECRYPTED_HASH SEED_TESTHASH
}

# Main Execution Flow
echo "Seed encryptor with password key derivation."
read_word_file
ask_for_pass
ask_for_seed_to_encrypt
create_salt
encrypt_seed
check_decryption

echo ""
echo "Encrypted SEED: $SEED"
echo -n "Encrypted SEED Hash: "
echo -n "$SEED" | sha512sum | cut -d " " -f 1

# Clear remaining global output variables
unset SEED WORDARRAY WORDMAP NAME
