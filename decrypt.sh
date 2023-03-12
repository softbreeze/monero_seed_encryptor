#!/bin/bash

function  read_word_file {
  words=0
  while IFS='' read -r line || [[ -n "$line" ]]; do
      #echo "Text read from file: $line"
      let words=words+1
      WORDARRAY["$words"]="$line"
  done < "wordlist.txt"
  echo We have $words words.
}

function ask_for_pass {
  echo "Name of the key:"
  read NAME
  echo "Password: "
  read -s PASS
  PASS="$NAME$PASS"
}

function ask_for_seed_to_decrypt {
  echo "Type encrypted seed:"
  read -s SEED
}

function create_salt {
  echo "It will take a lot of time..."
  for n in {1..100}
  do
    for i in {1..1000}
    do
      PASS=`echo "$PASS" | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev `
    done
    PASS_FINAL=$PASS_FINAL$PASS
    echo -n "#"
  done
  PASS_FINAL=`echo "$PASS_FINAL" | tr "a-j" "0-9" | tr "k-t" "0-9" | tr "u-z" "0-9" | rev | cut -c1-120`
  echo ""
  echo "Key created. Now decrypting seed."
  #echo "$PASS_FINAL"
}


function check_decryption {
  COUNTER1=1
  COUNTER2=0

  for i in {1..24}
  do
    let COUNTER2=COUNTER1+4
    TMPN=`echo $PASS_FINAL | cut -c $COUNTER1-$COUNTER2 | sed 's/^0*//' `
    until [[ $TMPN -le $words ]]; do
      let TMPN=TMPN-words
    done
    SEED_DECRYPTED=`echo "$SEED" | cut -d "-" -f $i`
    let COUNTER1=COUNTER1+5
    #echo -n "$SEED_DECRYPTED minus $TMPN equals"
    until [[ $TMPN -le $words ]]; do
      let TMPN=TMPN-words
    done
    let SEED_DECRYPTED=SEED_DECRYPTED-TMPN
    until [[ $SEED_DECRYPTED -gt 0 ]]; do
      let SEED_DECRYPTED=SEED_DECRYPTED+words
    done
    until [[ $SEED_DECRYPTED -le $words ]]; do
      let SEED_DECRYPTED=SEED_DECRYPTED-words
    done
    #echo " $SEED_DECRYPTED, which is ${WORDARRAY[$SEED_DECRYPTED]}"
    SEED_DECRYPTED_FINAL="$SEED_DECRYPTED_FINAL ${WORDARRAY[$SEED_DECRYPTED]}"
    #echo $SEED_DECRYPTED_FINAL
    SEED_DECRYPTED=""

  done
  echo "--------------------------------------------------------------------------------------------------------------------------------------------"
  echo -n "Decrypted seed is: "
  echo $SEED_DECRYPTED_FINAL
  echo -n "Decrypted SEED Hash: "
  echo $SEED_DECRYPTED_FINAL | sha512sum | cut -d " " -f 1
  echo "--------------------------------------------------------------------------------------------------------------------------------------------"

}


echo "Seed decryptor with a pass."
read_word_file
ask_for_pass
ask_for_seed_to_decrypt
create_salt
check_decryption
