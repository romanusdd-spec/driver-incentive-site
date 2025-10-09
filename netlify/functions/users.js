// netlify/functions/users.js
// Using SHA-256 hex hashes to match current passwords:
// dodi  -> dodi123
// alice -> alice123
// bob   -> bob123
export const USERS = {
  dodi:  "cfc2644cf97098d0c2fe7b8f5c366f495260f77b291f3987f02fa340e7165e1d",
  alice: "4e40e8ffe0ee32fa53e139147ed559229a5930f89c2204706fc174beb36210b3",
  bob:   "8d059c3640b97180dd2ee453e20d34ab0cb0f2eccbe87d01915a8e578a202b11"
};
