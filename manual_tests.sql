-- Online store database: manual tests

-- 1) create a customer and products
insert into customers (full_name, email, balance)
values ('Test Customer', 'test.customer@example.com', 1780);

insert into products (product_name, price, stock_quantity)
values ('Phone', 47000, 100),
       ('Headphones', 1500, 9);

select * from customers;   --successfully
select * from products;    --successfully


-- 2) create an order with the procedure
call create_order(1);
select * from orders;            -- 1 order, total_amount = 0, successfully


-- 3) order creation is logged
select * from order_log;         -- successfully


-- 4) add products to the order
call add_product_to_order(1, 1, 4);   -- 4 phones
call add_product_to_order(1, 2, 2);   -- 2 headphones
select * from order_items;            -- 2 rows, price copied from products, successfully


-- 5) total is updated automatically
select order_id, total_amount from orders where order_id = 1;
-- 4 * 47000 + 2 * 1500 = 191000
select calculate_order_total(1);      -- 191000, successfully


-- 6) stock decreases
select product_name, stock_quantity from products;
-- Phone 96, Headphones 7, successfully


-- 7) trigger also works on delete
delete from order_items where order_item_id = 2;
select total_amount from orders where order_id = 1;   -- 188000, successfully
-- note: deleting an item does not return it to stock


-- 8) query analysis
explain analyze
select
    oi.order_id,
    p.product_name,
    oi.quantity,
    oi.price,
    oi.quantity * oi.price as item_total
from order_items oi
join products p on oi.product_id = p.product_id
where oi.order_id = 1;
-- full analyze in README

-- 9) error cases (each CALL fail with a message)
-- call add_product_to_order(1, 2, 100);  -- Not enough stock
-- call add_product_to_order(1, 2, 0);    -- Quantity must be greater than 0
-- call add_product_to_order(1, 99, 1);   -- Product 99 does not exist
-- call create_order(99);                 -- Customer 99 does not exist
