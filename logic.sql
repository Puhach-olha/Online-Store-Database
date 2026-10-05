-- Online store database: function, procedures, triggers


-- ===== FUNCTION: calculate_order_total =====
-- returns the sum of quantity * price for all items in order
create or replace function calculate_order_total(p_order_id int)
returns numeric
language plpgsql
as
$$
declare
    total numeric;
begin
    select coalesce(sum(oi.quantity * oi.price), 0)
    into total
    from order_items as oi
    where oi.order_id = p_order_id;

    return total;
end;
$$;



-- ===== PROCEDURE: create_order =====
-- creates an empty order for an existing customer
create or replace procedure create_order(p_customer_id int)
language plpgsql
as
$$
begin
    if not exists (select 1 from customers where customer_id = p_customer_id) then
        raise exception 'Customer % does not exist', p_customer_id;
    end if;

    insert into orders (customer_id, order_date, total_amount)
    values (p_customer_id, current_timestamp, 0);
end;
$$;



-- ===== PROCEDURE: add_product_to_order =====
-- adds a product to an order, takes the current price from products and decreases the stock
create or replace procedure add_product_to_order(
    p_order_id int,
    p_product_id int,
    p_quantity int
)
language plpgsql
as
$$
declare
    v_price numeric(10,2);
    v_stock int;
begin
    -- quantity must be positive
    if p_quantity <= 0 then
        raise exception 'Quantity must be greater than 0';
    end if;

    if not exists (select 1 from orders where order_id = p_order_id) then
        raise exception 'Order % does not exist', p_order_id;
    end if;

    -- for update locks the product row, so two people
    -- cannot buy the last items at the same time
    select stock_quantity, price
    into v_stock, v_price
    from products
    where product_id = p_product_id
    for update;

    if not found then
        raise exception 'Product % does not exist', p_product_id;
    end if;

    -- not enough stock
    if v_stock < p_quantity then
        raise exception 'Not enough stock: available %, requested %', v_stock, p_quantity;
    end if;

    insert into order_items (order_id, product_id, quantity, price)
    values (p_order_id, p_product_id, p_quantity, v_price);

    update products
    set stock_quantity = stock_quantity - p_quantity
    where product_id = p_product_id;
end;
$$;



-- ===== TRIGGER: update order total =====
-- recalculates orders.total_amount when order_items changes
create or replace function fnc_recalculate_total_amount()
returns trigger
language plpgsql
as
$$
begin
   -- coalesce тут для того щоб вибирав не null, бо при insert існує тільки new,при update both, при delete тільки old
    update orders
    set total_amount = calculate_order_total(coalesce(new.order_id, old.order_id))
    where order_id = coalesce(new.order_id, old.order_id);

    return null;
end;
$$;

create or replace trigger trg_recalculate_total_amount
after insert or update or delete
on order_items
for each row
execute function fnc_recalculate_total_amount();



-- ===== TRIGGER: order audit log =====
-- writes a row to order_log every time an order is created
create or replace function fnc_order_audit_log()
returns trigger
language plpgsql
as
$$
begin
    insert into order_log (order_id, customer_id, action, log_date)
    values (new.order_id, new.customer_id, 'created', current_timestamp);

    return null;
end;
$$;

create or replace trigger trg_order_audit_log
after insert
on orders
for each row
execute function fnc_order_audit_log();
