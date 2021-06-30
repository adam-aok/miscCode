/* Simple interview question to pull a list of account IDs from a database which are duplicated in the table. 9-23-2020 */
SELECT id, COUNT(id)
FROM db_accounts
GROUP by id
HAVING COUNT(id) > 1

