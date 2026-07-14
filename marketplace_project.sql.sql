-- 1.revenue vs profit reality
select sum(o.guantity*o.selling_price) as total_sales_revenue,
sum(o.guantity * pr.cost_price) as total_cost,
sum((o.guantity*o.selling_price)-(o.guantity * pr.cost_price))
as total_profit
from orders_v2 o
join products_v2 pr on o.product_id = pr.product_id;


-- 2.categorywise sales and profit
select pr.category,
 sum(o.guantity*o.selling_price) as total_sales_revenue,
sum(o.guantity * pr.cost_price) as total_cost,
sum((o.guantity*o.selling_price)-(o.guantity * pr.cost_price))
as total_profit
from orders_v2 o
join products_v2 pr on o.product_id = pr.product_id
group by pr.category
order by total_profit desc;


-- 3.loss making product
select pr.product_id,pr.category,
sum(o.guantity * (o.selling_price - pr.cost_price))as total_profit
from orders_v2 o 
join products_v2 pr on o.product_id=pr.product_id
group by pr.product_id
having sum(o.guantity*(o.selling_price-pr.cost_price))<0
order by total_profit asc;


-- 4.discount usage overview
use market_place;

select count(distinct order_id)as discount_orders,
sum(discount_amount) as total_discount_amount
from discounts_v2;

-- 5.payment method popularity
select payment_method,
count(distinct order_id)as total_orders,
sum(guantity*selling_price) as total_sales_revenue
from orders_v2
group by payment_method;

-- 6.discount vs profit gaps
select 
case when discount_amount >0 then 'discounted orders'
else 'non-discounted orders'
end as order_type,
count(order_id) as total_orders,
avg(discount_amount) as avg_discount
from discounts_v2
group by order_type;

-- 7.return impact on revenue
select sum(o.guantity * o.selling_price)as total_revenue_lost,
sum((o.guantity * o.selling_price)-pr.cost_price)as total_profit_lost
from orders_v2 o 
join returns_v2 r on o.order_id=r.order_id
join products_v2 pr on o.product_id=pr.product_id;

-- 8.return reason analysis
select r.return_reason,
    COUNT(r.return_id) AS Total_Returns,
    SUM(o.guantity * o.selling_price) AS Total_Revenue_Lost
from returns_v2 r
join orders_v2 o
    on r.order_id = o.order_id 
group by r.return_reason
order by Total_Revenue_Lost desc;

-- 9.logistic cost burden
select o.order_id,
(o.guantity * o.selling_price) as order_value,
(l.shipping_cost + l.reverse_shipping_cost) as logistic_cost
from orders_v2 o
join logistics_cost_v2 l
on o.order_id = l.order_id
where (l.shipping_cost + l.reverse_shipping_cost)>0.2* (o.guantity * o.selling_price);

-- 10.payment fees leakage
select o.payment_method,
SUM(o.guantity * o.selling_price * pf.fee_percentage / 100) 
    as total_gateway_fee,
SUM((o.guantity * o.selling_price) - (o.guantity * pr.cost_price)) 
    as profit_before_fee,
SUM((o.guantity * o.selling_price) - (o.guantity * pr.cost_price)
        - (o.guantity * o.selling_price * pf.fee_percentage / 100)) 
    as net_profit
from orders_v2 o
join products_v2 pr on o.product_id = pr.product_id
join  payment_fees_v2 pf on o.payment_method=pf.payment_method
group by o.payment_method;

-- 11.revenue leakage breakdown
select sum(case when d.discount_amount is null
	then 0 else d.discount_amount 
    end ) as total_discount_loss,
sum(case when r.return_flag = 'Y'
	then o.guantity * o.selling_price else 0
    end ) as total_return_loss,
sum(case when l.shipping_cost is null and l.reverse_shipping_cost is null
	then 0 else l.shipping_cost + l.reverse_shipping_cost
    end
) as total_logistics_loss,
sum( case when  pf.fee_percentage is null then 0
        else (o.guantity* o.selling_price)*pf.fee_percentage/100
    end
) as total_payment_fee_loss
from orders_v2 o
left join  discounts_v2 d on o.order_id = d.order_id
left join returns_v2 r on o.order_id = r.order_id
left join logistics_cost_v2 l on o.order_id = l.order_id
left join payment_fees_v2 pf on o.payment_method = pf.payment_method;


-- 12.product profit ranking
select o.product_id,sum((o.guantity *o.selling_price)- (o.guantity* pr.cost_price))
as net_profit,
rank() over (
order by sum((o.guantity * o.selling_price)- (o.guantity* pr.cost_price))desc)
as product_rank
from orders_v2 o
join products_v2 pr on o.product_id = pr.product_id
group by o.product_id;


-- 13.category margin stability
select pr.category,
STDDEV((o.selling_price - pr.cost_price) / o.selling_price)as profit_margin_variation
from orders_v2 o
join products_v2 pr
on o.product_id = pr.product_id
group by pr.category
order by profit_margin_variation desc;

-- 14.high risk customer
select o.customer_id,
count(o.order_id) as total_orders,
sum(case when r.return_flag = 'Y' then 1 else 0 end) AS returned_orders,
sum(case when r.return_flag = 'Y' then 1 else 0 end) * 1.0 
	/ count(o.order_id) AS return_rate
from orders_v2 o
left join returns_v2 r on o.order_id = r.order_id
group by o.customer_id
having return_rate > (
select avg(case when r.return_flag = 'Y' then 1.0 else 0 end)
from returns_v2 r
);

-- 15.executive profitability summary
select sum(o.guantity*o.selling_price) as total_sales,
sum((o.guantity*o.selling_price)- (o.guantity*pr.cost_price))as total_profit,
sum(d.discount_amount)as total_discounts,
sum(case
 when r.return_flag='y'
then o.guantity * o.selling_price else 0
end) as total_return_loss,
sum(l.shipping_cost + l.reverse_shipping_cost)as total_logistic_cost,
sum((o.guantity*o.selling_price)*(pf.fee_percentage/100))as total_payment_fees
from orders_v2 o
join products_v2 pr on o.product_id=pr.product_id
left join returns_v2 r on o.order_id=r.order_id
left join logistics_cost_v2 l on o.order_id=l.order_id
left join payment_fees_v2 pf on o.payment_method=pf.payment_method
left join discounts_v2 d on o.order_id=d.order_id;

