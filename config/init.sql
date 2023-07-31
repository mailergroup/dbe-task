-- DDL for the new shop table
CREATE TABLE shop_stores (
  shop_id INT PRIMARY KEY,
  shop_name  VARCHAR(100),
  description VARCHAR(500)
)
WITH (FILLFACTOR = 70);

CREATE TABLE customers (
  customer_id INT PRIMARY KEY,
  shop_id INT NOT NULL,
  first_name VARCHAR(50) NOT NULL,
  last_name VARCHAR(50) NOT NULL,
  email VARCHAR(100) NOT NULL,
  address VARCHAR(200),
  phone_number VARCHAR(20),
  CONSTRAINT fk_customers_shop_stores FOREIGN KEY(shop_id) REFERENCES public.shop_stores (shop_id)
) partition by range (customer_id);

CREATE INDEX IF NOT EXISTS customers_customer_id_index on customers using btree (customer_id);
CREATE INDEX IF NOT EXISTS customers_fk_shop_id_index on customers using btree (shop_id);

SELECT create_parent( p_parent_table => 'public.customers', p_control => 'customer_id', p_type => 'native', p_interval=> '1000', p_premake => 5);

UPDATE part_config SET infinite_time_partitions = true,    retention_keep_table=true WHERE parent_table = 'public.customers';
SELECT cron.schedule('@daily', $$CALL partman.run_maintenance_proc()$$);

CREATE TABLE orders (
  order_id INT PRIMARY KEY,
  customer_id INT NOT NULL,
  shop_id INT NOT NULL,
  order_date DATE NOT NULL,
  total_amount DECIMAL(10, 2),
  CONSTRAINT fk_orders_customers FOREIGN KEY(customer_id) REFERENCES public.customers (customer_id) ,
	CONSTRAINT fk_orders_shop_stores FOREIGN KEY(shop_id) REFERENCES public.shop_stores (shop_id)
) 
WITH (FILLFACTOR = 70);

CREATE INDEX IF NOT EXISTS orders_fk_customer_id_index ON public.orders using btree (customer_id);
CREATE INDEX IF NOT EXISTS orders_fk_shop_id_index ON public.orders using btree (shop_id);
CREATE INDEX IF NOT EXISTS orders_order_date_index  ON public.orders using btree (order_date);
CREATE INDEX IF NOT EXISTS orders_order_date_order_date_idx on public.orders USING btree  (order_date , order_date);
CREATE INDEX IF NOT EXISTS orders_customer_id_order_date_index ON public.orders using btree (customer_id,order_date);

CREATE TABLE products (
  product_id INT PRIMARY KEY,
  shop_id INT NOT NULL,
  product_name VARCHAR(100) NOT NULL,
  price INT NOT NULL,
  description VARCHAR(500),
  CONSTRAINT fk_products_shop_stores FOREIGN KEY(shop_id) REFERENCES public.shop_stores (shop_id)
)WITH (FILLFACTOR = 70);
             
CREATE INDEX CONCURRENTLY IF NOT EXISTS products_product_id_index on products using btree (product_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS products_fk_shop_id_index on products using btree (shop_id);

CREATE TABLE order_Items (
  order_item_id INT PRIMARY KEY,
  order_id INT NOT NULL,
  product_id INT NOT NULL,
  shop_id INT NOT NULL,
  quantity INT,
  subtotal DECIMAL(10, 2),
  CONSTRAINT fk_customers_shop_stores FOREIGN KEY(shop_id) REFERENCES public.shop_stores (shop_id),
 CONSTRAINT fk_customers_orders FOREIGN KEY(order_id) REFERENCES public.orders (order_id),
CONSTRAINT fk_customers_products FOREIGN KEY(product_id) REFERENCES public.products  (product_id)
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS order_Items_fk_order_id_index on order_Items using btree (order_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS order_Items_fk_product_id_index on order_Items using btree (product_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS order_Items_fk_shop_id_index on order_Items using btree (shop_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS order_Items_quantity_index on order_Items using btree (quantity);

-- Specify the desired number of rows for each table here
DO $$DECLARE
  shop_count INT := 100;
  shop_stores_count INT := 101;
  customer_count INT := 3000;
  order_count INT := 20000;
  product_count INT := 1000;
BEGIN
  -- Generating sample data for the shop_store table
  INSERT INTO shop_stores (shop_id, shop_name, description)
        select  row_number() OVER () as shop_id,
	        'Shop' || row_number() OVER () as shop_name,
      'Description for Shop' || row_number() OVER () as description
  FROM generate_series(1, shop_stores_count) AS t;

  -- Generating sample data for the customers table
  INSERT INTO customers (customer_id, shop_id, first_name, last_name, email, address, phone_number)
  SELECT
      row_number() OVER () as customer_id,
      (random() * shop_count + 1)::numeric(10, 2) as shop_id,
      'First' || row_number() OVER () as first_name,
      'Last' || row_number() OVER () as last_name,
      'customer' || row_number() OVER () || '@example.com' as email,
      'Address' || row_number() OVER () as address,
      '555-' || lpad((row_number() OVER ())::text, 4, '0')
  FROM generate_series(1, customer_count) AS t;

  -- Generating sample data for the orders table
  INSERT INTO orders (order_id, customer_id, shop_id, order_date, total_amount)
  SELECT
      row_number() OVER () as order_id,
      (SELECT customer_id FROM customers WHERE shop_id = c.shop_id ORDER BY random() LIMIT 1) as customer_id,
      c.shop_id,
      CURRENT_DATE - (row_number() OVER () % 30 + 1) * INTERVAL '1 day' as order_date,
      (random() * 1000 + 1)::numeric(10, 2) as total_amount
  FROM generate_series(1, order_count) AS t
  JOIN customers c ON c.customer_id = (t % customer_count) + 1
  ORDER BY t;

  -- Generating sample data for the products table
  INSERT INTO products (product_id, shop_id, product_name, price, description)
  SELECT
      row_number() OVER () as product_id,
      (random() * shop_count + 1)::numeric(10, 2) as shop_id,
      'Product' || row_number() OVER () as product_name,
      (row_number() OVER ()) % 100 + 1 as price,
      'Description for Product' || row_number() OVER () as description
  FROM generate_series(1, product_count) AS t;

  -- Generating sample data for the order_items table
  INSERT INTO order_items (order_item_id, order_id, product_id, shop_id, quantity, subtotal)
  SELECT
      row_number() OVER () as order_item_id,
      o.order_id,
      (SELECT product_id FROM products WHERE shop_id = c.shop_id ORDER BY random() LIMIT 1) as product_id,
      c.shop_id,
      (random() * 10 + 1)::numeric(10, 2) as quantity,
      ((random() * 100 + 1) * (row_number() OVER () % 10 + 1))::numeric(10, 2) as subtotal
  FROM (
    SELECT order_id, (random() * 5 + 1)::integer AS num_items
    FROM orders
    ORDER BY order_id
    LIMIT order_count
  ) o
  JOIN customers c ON c.customer_id = (o.order_id % customer_count) + 1
  CROSS JOIN LATERAL (
    SELECT generate_series(1, num_items) -- Generate the specified number of order_items per order
  ) AS s
  ORDER BY o.order_id;
END$$;
