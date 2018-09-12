# Monero_seed_encryptor
Very simple bash script, which encrypts Monero's seed. An alternative to recently implemented Monero's native seed encryption, but decryption process takes much more time. Cracking the password should be much tougher. 

# Requirements
Linux, bash and sha512sum

# How it works
The script, based on the public wallet name and a secret password, generates a key used to encrypt a seed. The script calculates 1 Million sha512 hashes in the process.
The encrypted seed looks like this: 445-129-79-1570-1207-1488-87-1449-824-682-863-1379-437-1511-675-168-219-1183-1113-174-485-868-864-274. You should write it down together with the wallet name and only memorize the password.
Decrypting with a different password also leads to a valid seed, so if you want, you can also use many decoys.

# Usage
To encrypt type: ./encrypt.sh
To decrypt type: ./decrypt.sh
And follow the instructions from the script. Remember: it's case sensitiv!

# Security tips
Use it only offline on the dedicated computer. I've tested it on RaspberryPi 3 and it worked perfectly. De advised - it takes about 1 hour to generate the key on the RP3.
Never write the password down, only the encrypted seed and a name.
If you are afraid, that you can be forced to reveal the password, decrypt the encrypted seed with a different password and use the new seed to create a decoy wallet.

# Donations
If you like the idea, consider small donations.
Monero: 449t9UatsBf6utFeQEU3SLShucPEF21VZ8CJe9YePq3wDFvGWxGLasu4m6aEYr6px6QFRWBYQr2BMYsPBjUDUufjCyYgJMi
