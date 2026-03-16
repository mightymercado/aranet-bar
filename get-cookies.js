const alexaCookie = require('/Users/kenmercado/.nvm/versions/node/v24.4.1/lib/node_modules/alexa-cookie2/alexa-cookie');
const fs = require('fs');
const path = require('path');

const configDir = path.join(process.env.HOME, '.config', 'aranet-bar');
const cookiePath = path.join(configDir, 'alexa-cookies.txt');

const config = {
    logger: console.log,
    proxyOwnIp: '127.0.0.1',
    amazonPage: 'amazon.com',
    acceptLanguage: 'en-US',
    setupProxy: true,
    proxyOnly: true,
    proxyPort: 3456,
    proxyLogLevel: 'info',
    baseAmazonPage: 'amazon.com',
    amazonPageProxyLanguage: 'en_US',
};

console.log('\n=== Alexa Cookie Generator ===');
console.log('Open http://127.0.0.1:3456/ in your browser and log in.\n');

alexaCookie.generateAlexaCookie(config, (err, result) => {
    // First callback is the "please open browser" message — ignore it
    if (err && String(err).includes('Please open')) {
        return;
    }

    if (err) {
        console.error('Error:', err);
    }

    // result can be a string (loginCookie) or object {cookie, csrf}
    let cookie = null;
    if (result) {
        if (typeof result === 'string') {
            cookie = result;
            console.log('\nGot login cookie (string)');
        } else if (result.cookie) {
            cookie = result.cookie;
            console.log('\nGot full cookie with csrf:', result.csrf);
        } else if (result.loginCookie) {
            cookie = result.loginCookie;
            console.log('\nGot login cookie from result object');
        } else {
            console.log('\nUnexpected result format:', JSON.stringify(result).substring(0, 500));
        }
    }

    if (cookie) {
        fs.mkdirSync(configDir, { recursive: true });
        fs.writeFileSync(cookiePath, cookie);
        console.log('Cookies saved to:', cookiePath);
        console.log('Cookie length:', cookie.length, 'chars');
        alexaCookie.stopProxyServer();
        process.exit(0);
    } else {
        console.log('No cookie extracted. Raw result:', JSON.stringify(result).substring(0, 500));
    }
});
