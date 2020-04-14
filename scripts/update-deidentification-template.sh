OS=`uname`

if [ "$OS" = "Darwin" ]; then
    echo "Mac OS - executing sed for Mac."
    sed -i '' 's/REPLACE_WITH_YOUR_CRYPTO_KEY_NAME/projects\/'$PROJECT'\/locations\/'$LOCATION'\/keyRings\/dlp-encryption-keys\/cryptoKeys\/DlpCryptoKey/g' dlp-templates/deindentification-sensitive-data-with-enckvm-deterministic-key-template.json
    sed -i '' 's/REPLACE_WITH_YOUR_CRYPTO_KEY_NAME/projects\/'$PROJECT'\/locations\/'$LOCATION'\/keyRings\/dlp-encryption-keys\/cryptoKeys\/DlpCryptoKey/g' dlp-templates/deindentification-sensitive-data-with-enckvm-key-template.json
    echo "Find and replace was successful!"
else
    echo "Using standard linux sed."
    sed -i 's/REPLACE_WITH_YOUR_CRYPTO_KEY_NAME/projects\/'$PROJECT'\/locations\/'$LOCATION'\/keyRings\/dlp-encryption-keys\/cryptoKeys\/DlpCryptoKey/g' dlp-templates/deindentification-sensitive-data-with-enckvm-deterministic-key-template.json
    sed -i 's/REPLACE_WITH_YOUR_CRYPTO_KEY_NAME/projects\/'$PROJECT'\/locations\/'$LOCATION'\/keyRings\/dlp-encryption-keys\/cryptoKeys\/DlpCryptoKey/g' dlp-templates/deindentification-sensitive-data-with-enckvm-key-template.json
    echo "Find and replace was successful!"
fi