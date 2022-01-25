/* COPY companies(id, business_type, is_active)
FROM 'C:\Users\Public\avo-tmp\Home Assignment - Companies.csv'
DELIMITER ','
CSV HEADER; */

DELETE FROM orders;

COPY orders(company_id, orderID, totalSpend, date_completed_LocalTime, UserID)
FROM 'C:\Users\Public\avo-tmp\Home Assignment - Orders.csv'
DELIMITER ','
CSV HEADER;

SELECT * FROM companies;

DROP TABLE vert1;

CREATE TABLE vert1 AS 
  (SELECT companies.id,
   		  companies.business_type,
   		  companies.is_active,
          orders.orderid, 
          orders.totalspend, 
          orders.date_completed_localtime,
   		  orders.userid
   FROM   companies
          INNER JOIN orders ON companies.id = orders.company_id
  			WHERE companies.business_type = 1);
DROP TABLE vert2;			
			
CREATE TABLE vert2 AS 
  (SELECT companies.id,
   		  companies.business_type,
   		  companies.is_active,
          orders.orderid, 
          orders.totalspend, 
          orders.date_completed_localtime,
   		  orders.userid
   FROM   companies
          INNER JOIN orders ON companies.id = orders.company_id
  			WHERE companies.business_type = 2);
DROP TABLE vert3;

CREATE TABLE vert3 AS 
  (SELECT companies.id,
   		  companies.business_type,
   		  companies.is_active,
          orders.orderid, 
          orders.totalspend, 
          orders.date_completed_localtime,
   		  orders.userid
   FROM   companies
          INNER JOIN orders ON companies.id = orders.company_id
  			WHERE companies.business_type = 3);

CREATE TABLE unified AS 
  (SELECT companies.id,
   		  companies.business_type,
   		  companies.is_active,
          orders.orderid, 
          orders.totalspend, 
          orders.date_completed_localtime,
   		  orders.userid
   FROM   companies
          INNER JOIN orders ON companies.id = orders.company_id);