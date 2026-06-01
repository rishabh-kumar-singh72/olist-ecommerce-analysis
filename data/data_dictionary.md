# Data Dictionary — olist_master_clean.csv

**Dataset:** Olist Brazilian E-Commerce (Kaggle)
**Rows:** 96,469 delivered orders
**Date range:** September 2016 – August 2018

---

## Columns

| Column | Type | Description |
|--------|------|-------------|
| order_id | text | Unique identifier for each order |
| customer_id | text | Customer identifier linked to customers table |
| order_status | text | All rows = "delivered" in this cleaned dataset |
| order_purchase_timestamp | datetime | When the customer placed the order |
| order_approved_at | datetime | When payment was approved by Olist |
| order_delivered_customer_date | datetime | When the customer physically received the order |
| order_estimated_delivery_date | datetime | Estimated delivery date shown at purchase time |
| customer_state | text | Brazilian state (2-letter code e.g. SP, RJ, MG) |
| customer_city | text | Customer city name |
| actual_delivery_days | integer | Days from purchase to delivery (engineered column) |
| is_late | boolean | TRUE if delivered after estimated date |
| delivery_delay_days | integer | Days late (+) or early (-) vs estimated date |
| order_hour | integer | Hour of day order was placed (0–23) |
| order_dayofweek | text | Day of week order was placed (Monday–Sunday) |
| order_month | text | Year-month period e.g. 2017-11 |
| delivery_status | text | "Late" or "On Time" |
| delay_bucket | text | Grouped delay: Early 7+d / On time / Late 1-7d / Very late 7+d |
| total_payment | float | Total amount paid in Brazilian Real (R$) |
| review_score | integer | Customer review 1–5 (1 = worst, 5 = best) |
| category | text | Product category in English |
| payment_type | text | credit_card / boleto / voucher / debit_card |

---

## Engineered Columns (created in Python)

These columns did not exist in the original Kaggle dataset.
They were created during the cleaning phase in `01_data_cleaning.ipynb`:

- **actual_delivery_days** = order_delivered_customer_date - order_purchase_timestamp
- **is_late** = order_delivered_customer_date > order_estimated_delivery_date
- **delivery_delay_days** = order_delivered_customer_date - order_estimated_delivery_date
- **delivery_status** = "Late" if is_late else "On Time"
- **delay_bucket** = grouped delay category using numpy.select()
- **order_hour** = hour extracted from order_purchase_timestamp
- **order_dayofweek** = day name extracted from order_purchase_timestamp

---

## Data Quality Notes

| Issue | Rows affected | How handled |
|-------|--------------|-------------|
| Non-delivered orders removed | ~2,400 | Filtered: order_status = 'delivered' only |
| Missing delivery dates | ~300 | Dropped — status said delivered but no date |
| Impossible delivery dates | ~50 | Dropped — delivered before purchase date |
| Missing review scores | ~8,000 | Kept — NaN preserved, excluded from review analysis |
| Missing category names | ~100 | Filled with "unknown" |

---

*Source: [Olist Brazilian E-Commerce Dataset on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)*
