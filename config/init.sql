CREATE TABLE customers (
  customer_id INT PRIMARY KEY,
  shop_id INT,
  first_name VARCHAR(50),
  last_name VARCHAR(50),
  email VARCHAR(100),
  address VARCHAR(200),
  phone_number VARCHAR(20)
);

CREATE TABLE orders (
  order_id INT PRIMARY KEY,
  customer_id INT,
  shop_id INT,
  order_date DATE,
  total_amount DECIMAL(10, 2)
);

CREATE TABLE products (
  product_id INT PRIMARY KEY,
  shop_id INT,
  product_name VARCHAR(100),
  price INT,
  description VARCHAR(500)
);

CREATE TABLE order_Items (
  order_item_id INT PRIMARY KEY,
  order_id INT,
  product_id INT,
  shop_id INT,
  quantity INT,
  subtotal DECIMAL(10, 2)
);

-- Specify the desired number of rows for each table here
DO $$DECLARE
  shop_count INT := 100;
  customer_count INT := 3000;
  order_count INT := 20000;
  product_count INT := 1000;
BEGIN
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
