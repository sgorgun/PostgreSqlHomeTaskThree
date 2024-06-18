-- 1. Write a query that will return for each year the most popular in rental film among films released in one year.
SELECT DISTINCT ON (release_year)
    f.release_year,
    f.title,
    COUNT(r.rental_id) AS rental_count
FROM
    film f
JOIN
    inventory i ON f.film_id = i.film_id
JOIN
    rental r ON i.inventory_id = r.inventory_id
GROUP BY
    f.release_year, f.film_id
ORDER BY
    release_year, rental_count DESC;

--2. Write a query that will return the Top-5 actors who have appeared in Comedies more than anyone else.
SELECT 
    a.actor_id, 
    a.first_name, 
    a.last_name, 
    COUNT(fa.film_id) AS comedy_count
FROM 
    actor a
JOIN 
    film_actor fa ON a.actor_id = fa.actor_id
JOIN 
    film_category fc ON fa.film_id = fc.film_id
JOIN 
    category c ON fc.category_id = c.category_id
WHERE 
    c.name = 'Comedy'
GROUP BY 
    a.actor_id, a.first_name, a.last_name
ORDER BY 
    comedy_count DESC
LIMIT 5;

--3. Write a query that will return the names of actors who have not starred in “Action” films
SELECT a.first_name, a.last_name
FROM actor a
WHERE NOT EXISTS (
    SELECT fa.actor_id
    FROM film_actor fa
    JOIN film_category fc ON fa.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    WHERE fa.actor_id = a.actor_id
      AND c.name = 'Action'
)
ORDER BY a.last_name, a.first_name;

--4. Write a query that will return the three most popular in rental films by each genre.
SELECT 
    genre, 
    film_id, 
    title, 
    rental_count
FROM (
    SELECT 
        c.name AS genre,
        f.film_id,
        f.title,
        COUNT(r.rental_id) AS rental_count,
        ROW_NUMBER() OVER (PARTITION BY c.name ORDER BY COUNT(r.rental_id) DESC) AS row_num
    FROM 
        film f
    JOIN 
        film_category fc ON f.film_id = fc.film_id
    JOIN 
        category c ON fc.category_id = c.category_id
    JOIN 
        inventory i ON f.film_id = i.film_id
    JOIN 
        rental r ON i.inventory_id = r.inventory_id
    GROUP BY 
        c.name, f.film_id, f.title
) subquery
WHERE row_num <= 3
ORDER BY genre, row_num;

--5. Calculate the number of films released each year and cumulative total by the number of films. Write two query versions, one with window functions, the other without.
SELECT 
    release_year AS year,
    COUNT(film_id) AS films_released,
    SUM(COUNT(film_id)) OVER (ORDER BY release_year) AS cumulative_films_released
FROM
    film
GROUP BY
    release_year
ORDER BY
    release_year;
	
--	
WITH yearly_film_counts AS (
    SELECT
        release_year AS release_year,
        COUNT(film_id) AS films_released
    FROM
        film
    GROUP BY
        release_year
)
SELECT
    release_year,
    films_released,
    (SELECT SUM(films_released)
     FROM yearly_film_counts cumulative
     WHERE cumulative.release_year <= yearly.release_year) AS cumulative_films_released
FROM
    yearly_film_counts yearly
ORDER BY
    release_year;	

--6. Calculate a monthly statistics based on “rental_date” field from “Rental” table that for each month will show the percentage of “Animation” films from the total number of rentals. Write two query versions, one with window functions, the other without.
WITH months AS (
    SELECT DISTINCT TO_CHAR(r.rental_date, 'Month') AS rental_month
    FROM rental r
),
rentals_with_animation AS (
    SELECT
        TO_CHAR(r.rental_date, 'Month') AS rental_month,
        COUNT(*) OVER (PARTITION BY TO_CHAR(r.rental_date, 'Month')) AS total_rentals,
        COUNT(*) FILTER (WHERE c.name = 'Animation') OVER (PARTITION BY TO_CHAR(r.rental_date, 'Month')) AS animation_rentals
    FROM
        rental r
        LEFT JOIN inventory i ON r.inventory_id = i.inventory_id
        LEFT JOIN film_category fc ON i.film_id = fc.film_id
        LEFT JOIN category c ON fc.category_id = c.category_id
)
SELECT
    m.rental_month,
    COALESCE(rwa.animation_rentals, 0) AS animation_rentals,
    COALESCE(rwa.total_rentals, 0) AS total_rentals,
    ROUND((COALESCE(rwa.animation_rentals, 0)::DECIMAL / COALESCE(rwa.total_rentals, 1)::DECIMAL) * 100, 2) || '%' AS animation_percentage
FROM
    months m
    LEFT JOIN (
        SELECT DISTINCT
            rental_month,
            animation_rentals,
            total_rentals
        FROM
            rentals_with_animation
    ) rwa ON m.rental_month = rwa.rental_month
ORDER BY
    TO_DATE(m.rental_month, 'Month');

--
SELECT
    rental_month,
    COALESCE(animation_rentals, 0) AS animation_rentals,
    total_rentals,
    ROUND((COALESCE(animation_rentals, 0)::DECIMAL / total_rentals::DECIMAL) * 100, 2) || '%' AS animation_percentage
FROM (
    SELECT
        TO_CHAR(r.rental_date, 'Month') AS rental_month,
        COUNT(*) FILTER (WHERE c.name = 'Animation') AS animation_rentals,
        COUNT(*) AS total_rentals
    FROM
        rental r
        JOIN inventory i ON r.inventory_id = i.inventory_id
        JOIN film_category fc ON i.film_id = fc.film_id
        JOIN category c ON fc.category_id = c.category_id
    GROUP BY
        TO_CHAR(r.rental_date, 'Month')
    ORDER BY
        TO_CHAR(r.rental_date, 'Month')
) AS monthly_stats
ORDER BY
    TO_DATE(rental_month, 'Month');

--7.Write a query that will return the names of actors who have starred in “Action” films more than in “Drama” film.
SELECT 
    a.first_name,
    a.last_name,
    SUM(CASE WHEN c.name = 'Action' THEN 1 ELSE 0 END) AS action_films_count,
    SUM(CASE WHEN c.name = 'Drama' THEN 1 ELSE 0 END) AS drama_films_count
FROM
    actor a
JOIN
    film_actor fa ON a.actor_id = fa.actor_id
JOIN
    film f ON fa.film_id = f.film_id
JOIN
    film_category fc ON f.film_id = fc.film_id
JOIN
    category c ON fc.category_id = c.category_id
GROUP BY
    a.actor_id, a.first_name, a.last_name
HAVING
    SUM(CASE WHEN c.name = 'Action' THEN 1 ELSE 0 END) >
    SUM(CASE WHEN c.name = 'Drama' THEN 1 ELSE 0 END);

--8. Write a query that will return the top-5 customers who spent the most money watching Comedies.
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    SUM(p.amount) AS total_spent
FROM
    customer c
JOIN
    payment p ON c.customer_id = p.customer_id
JOIN
    rental r ON p.rental_id = r.rental_id
JOIN
    inventory i ON r.inventory_id = i.inventory_id
JOIN
    film_category fc ON i.film_id = fc.film_id
JOIN
    category cat ON fc.category_id = cat.category_id
WHERE
    cat.name = 'Comedy'
GROUP BY
    c.customer_id, c.first_name, c.last_name
ORDER BY
    total_spent DESC
LIMIT 5;

--9.In the “Address” table, in the “address” field, the last word indicates the "type" of a street: Street, Lane, Way, etc. Write a query that will return all "types" of streets and the number of addresses related to this "type"
SELECT
    REGEXP_REPLACE(address, '.*\s', '') AS street_type,
    COUNT(*) AS address_count
FROM
    address
GROUP BY
    street_type
ORDER BY
    address_count DESC;

--10. Write a query that will return a list of movie ratings, indicate for each rating the total number of films with this rating, the top-3 categories by the number of films in this category and the number of film in this category with this rating. The result can be like this:
WITH TotalFilmsPerRating AS (
    SELECT
        f.rating AS rating,
        COUNT(*) AS total
    FROM
        film f
    GROUP BY
        f.rating
),
TopCategoriesPerRating AS (
    SELECT
        f.rating AS rating,
        c.name AS category_name,
        COUNT(*) AS films_in_category,
        ROW_NUMBER() OVER (PARTITION BY f.rating ORDER BY COUNT(*) DESC) AS category_rank
    FROM
        film f
    JOIN
        film_category fc ON f.film_id = fc.film_id
    JOIN
        category c ON fc.category_id = c.category_id
    GROUP BY
        f.rating, c.name
)
SELECT
    tfr.rating,
    tfr.total,
    MAX(CASE WHEN tcpr.category_rank = 1 THEN tcpr.category_name || ': ' || tcpr.films_in_category ELSE NULL END) AS category1,
    MAX(CASE WHEN tcpr.category_rank = 2 THEN tcpr.category_name || ': ' || tcpr.films_in_category ELSE NULL END) AS category2,
    MAX(CASE WHEN tcpr.category_rank = 3 THEN tcpr.category_name || ': ' || tcpr.films_in_category ELSE NULL END) AS category3
FROM
    TotalFilmsPerRating tfr
JOIN
    TopCategoriesPerRating tcpr ON tfr.rating = tcpr.rating
GROUP BY
    tfr.rating, tfr.total
ORDER BY
    tfr.total DESC;
