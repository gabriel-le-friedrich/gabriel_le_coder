/* temporary syntax-check file — safe to delete */
import { initializeApp } from 'firebase/app';
const AsfAuth = {
  async init(){
    /* comment test: Firebase's own
       session (kept in the Keychain/EncryptedSharedPreferences on native,
       IndexedDB on web) is checked here, once, on every app launch. */
    return 1;
  },
};
console.log(AsfAuth);
