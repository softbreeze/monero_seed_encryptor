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

function ask_for_seed_to_encrypt {
  echo "Type seed (only 24 first words using only small letters):"
  read -s SEED_TO_ENCRYPT
  for i in {1..24}
  do
    #echo "Searching for word number $i"
    CURRENT_WORD=`echo "$SEED_TO_ENCRYPT" | cut -d " " -f $i`
    #echo $CURRENT_WORD
    x=1
    while [[ $x -le $words ]]
    do
      if [ -z "$CURRENT_WORD" ];
      then
        #echo "Too short"
        ((x = x + 10000))
      else
        if [[ "$CURRENT_WORD" == "${WORDARRAY[$x]}" ]]
        then
          SEEDARRAY["$i"]="$x"
          #echo "$CURRENT_WORD is ${SEEDARRAY[$i]} th word."
          unset $CURRENT_WORD
          ((x = x + 10000))
        fi
      fi
      ((x = x + 1))
    done


  done
}

function create_salt {
  echo "It will take a lot of time..."
  for n in {1..100}
  do
    for i in {1..1000}
    do
      PASS=`echo "$PASS" | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev | sha512sum | cut -d " " -f 1 | rev `
    done
    PASS_FINAL="$PASS_FINAL$PASS"
    echo -n "#"
  done
  PASS_FINAL=`echo "$PASS_FINAL" | tr "a-j" "0-9" | tr "k-t" "0-9" | tr "u-z" "0-9" | rev | cut -c1-120`
  echo ""
  echo "Key created. Now encrypting seed."
  #echo "$PASS_FINAL"
}

function encrypt_seed {
  COUNTER1=1
  COUNTER2=0

  for i in {1..24}
  do
    let COUNTER2=COUNTER1+4
    TMPN=`echo $PASS_FINAL | cut -c $COUNTER1-$COUNTER2 | sed 's/^0*//' `
    until [[ $TMPN -le $words ]]; do
      let TMPN=TMPN-words
    done
    let COUNTER1=COUNTER1+5
    #echo -n $TMPN
    TMPN2=${SEEDARRAY[$i]}
    let TMPN=TMPN+TMPN2
    unset TMPN2
    LENGHT=`echo -n $SEED | wc -m`
    if [ $LENGHT -eq 0 ]
    then
      SEED="$TMPN"
    else
      SEED="$SEED-$TMPN"
    fi
    #echo " $TMPN"

  done

}

function check_decryption {
  echo "Checking if decryption works."
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
    let SEED_DECRYPTED=SEED_DECRYPTED-TMPN
    #echo " $SEED_DECRYPTED, which is ${WORDARRAY[$SEED_DECRYPTED]}"
    SEED_DECRYPTED_FINAL="$SEED_DECRYPTED_FINAL ${WORDARRAY[$SEED_DECRYPTED]}"
    SEED_DECRYPTED=""

  done
  echo -n "Decrypted seed is: "
  echo $SEED_DECRYPTED_FINAL | cut -c1-20
  echo "Check if the begining it's identical with your input seed."
  echo "Decryption test finished."

}


echo "Seed encryptor with a pass."
echo "Only 24 words seeds are encrypted, becouse 25th is only a checksum."
read_word_file
ask_for_pass
ask_for_seed_to_encrypt
create_salt
encrypt_seed
check_decryption
echo ""
echo $SEED
