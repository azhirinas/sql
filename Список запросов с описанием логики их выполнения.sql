1. В каких городах больше одного аэропорта?

Логика: В таблице airports делаем группировку по городу (city)
и отбираем значения, где количество строк больше одной.

select 	 city 
from 	 airports 
group by city
having 	 count(*) > 1

2. В каких аэропортах есть рейсы, выполняемые самолетом
с максимальной дальностью перелета?

Логика: В подзапросе в таблице aircraft находим максимальное значение 
максимальной дальности полета (range) и затем в еще одном подзапросе 
в таблице aircraft отбираем код самолета (aircraft_code),
соответствующий отобранному максимальному значению. 
Из таблицы flights отбираем рейсы, соответствующие отобранному 
в подзапросе коду самолета. При помощи inner join подтягиваем 
из таблицы airports названия аэропортов (airport_name).

select 	 f.departure_airport as airport,
		 a.airport_name
from 	 flights f
	 	 inner join airports a on f.departure_airport = a.airport_code 
where 	 aircraft_code = (
					  	 select aircraft_code
					  	 from aircrafts 
					  	 where range = (select max(range) from aircrafts)
					  	 )
group by f.departure_airport,
		 a.airport_name

3. Вывести 10 рейсов с максимальным временем задержки вылета.

Логика: Задержку вылета можно вычислить только по тем рейсам, 
которые уже вылетели, поэтому отбираем из таблицы flights те строки, 
где указано фактическое время вылета (actual_departure). 
Сортируем по убыванию по времени задержки (actual_departure – 
scheduled_departure) и оставляем 10 верхних строк.

select 	 flight_no,
		 scheduled_departure,
		 actual_departure,
		 actual_departure - scheduled_departure as delay
from 	 flights f
where 	 actual_departure is not null
order by actual_departure - scheduled_departure  desc
limit 	 10

4. Были ли брони, по которым не были получены посадочные талоны?

Логика: Вопрос, как мне кажется, актуален только для тех рейсов, 
которые находятся в воздухе или уже прибыли, для рейсов с остальными статусами
очевидно, что посадочные талоны пока еще не получены. Поэтому в подзапросе 
отбираем из таблицы flights идентификаторы рейсов (flight_id) со статусом 
‘Departed’ и ‘Arrived’.
К таблице tickets через left join присоединяем таблицу boarding_passes.
Отбираем те строки, для которых в boarding_passes не найдется соответствия 
(boarding_no is null) и идентификаторы рейсов которых присутствуют в подзапросе.
При помощи case выводим ответ: если количество строк в результирующей таблице 
окажется больше нуля, получим ответ «были», в противном случае «не было».

select 	 case 
		 	when count(distinct book_ref) > 0 then 'были'
		 	else 'не было' 
		 end as answer
from 	 tickets t 
	 	 left join boarding_passes bp on t.ticket_no = bp.ticket_no
where 	 boarding_no is null
		 and flight_id in (
						  select flight_id
						  from flights
						  where status in ('Departed', 'Arrived')
						  )

5. Найдите свободные места для каждого рейса, их % отношение к общему количеству
мест в самолете.
Добавьте столбец с накопительным итогом - суммарное накопление количества
вывезенных пассажиров из каждого аэропорта на каждый день. Т.е. в этом столбце 
должна отражаться накопительная сумма - сколько человек уже вылетело из данного
аэропорта на этом или более ранних рейсах за день.

Логика: 5.	В подзапросе “c” делаем группировку по коду самолета (aircraft_code)
в таблице seats и считаем общее количество мест в самолете (capacity).
В подзапросе “o” делаем группировку по идентификатору рейса (flight_id) 
в таблице boarding_passes и считаем количество занятых мест (occupancy)
на каждом рейсе.
Объединяем таблицу flights при помощи inner join с таблицей airports, подтягивая
названия аэропортов. Объединяем также с двумя подзапросами, для объединения 
с “o” при этом используем left join, т.к. многие самолеты летают пустыми.
Данный запрос имеет смысл только для состоявшихся рейсов, поэтому в where 
отбираем те рейсы, у которых указано фактическое время вылета (actual_departure). 
Вычисляем количество свободных мест (avs_num), вычетая из общего количества мест
в самолете (capacity) количество занятых (occupancy). Вычисляем процент 
свободных мест, разделив количество свободных мест на общее количество мест 
в самолете и умножив на 100.
Для подсчета нарастающего итога по количеству вывезенных пассажиров считаем 
сумму по окну с разбавкой на секции по фактической дате отправления и аэропорту
отправления, а также с сортировкой по фактическому времени отправления.

select  f.flight_id,
		f.actual_departure,
		concat(airport_name , ' (', f.departure_airport, ')') as airport,
		c.capacity - coalesce(o.occupancy, 0) as avs_num, -- кол-во свободных мест
  		concat(
  			round(
  			(c.capacity - coalesce(o.occupancy, 0))
  			/ c.capacity :: numeric * 100), 
    		'%') as avs_perc, -- процент свободных мест
  		sum(
		    coalesce(o.occupancy, 0)) over (
		    	partition by date(f.actual_departure), departure_airport 
		    	order by actual_departure
		   ) as ctp -- нарастающий итог по кол-ву вывезенных пассажиров
from 	 flights f
		 inner join airports a on f.departure_airport = a.airport_code
		 inner join (
					select aircraft_code, count(*) as capacity
					from seats
					group by aircraft_code
					) c on f.aircraft_code = c.aircraft_code
		 left join 	(
					select flight_id, count(*) as occupancy
					from boarding_passes
					group by flight_id
					) o on f.flight_id = o.flight_id
where 	 actual_departure is not null
order by airport,
		 actual_departure

6. Найдите процентное соотношение перелетов по типам самолетов от общего 
количества.

Логика: В подзапросе находим общее количество рейсов в таблице flights.
В таблице flights делаем группировку по коду самолета (aircraft_code), 
считаем количество рейсов в рамках групп и делим на общее количество рейсов,
вычисленное в подзапросе. Для того, чтобы получить из этого числа проценты, 
умножаем на 100.
При помощи inner join подтягиваем из таблицы aircrafts модель самолета (model).

select 	 a.model,
		 concat(
		 	round(
		 	count(*)::numeric / (select count(*) from flights) * 100,
		 	2), '%') as "share"
from 	 flights f
		 inner join aircrafts a on f.aircraft_code = a.aircraft_code
group by a.aircraft_code
order by count(*)::numeric / (select count(*) from flights) desc
		
7. Были ли города, в которые можно  добраться бизнес-классом дешевле, 
чем эконом-классом в рамках перелета?

Логика: В подзапросе ‘e’ отбираем строки, соответствующие эконом-классу,
из таблицы ticket_flights, делаем группировку по идентификатору рейса
(flight_id) и находим максимальное значение тарифа эконом для каждого рейса. 
В подзапросе ‘b’ отбираем строки, соответствующие бизнес-классу, 
из таблицы ticket_flights, делаем группировку по идентификатору рейса
(flight_id) и находим минимальное значение тарифа бизнес для каждого рейса. 
Таблицу flights объединяем с двумя подзапросами, а также дважды с таблицей 
airports, присвоив разные алиасы, чтобы подтянуть названия городов.
Делаем выборку с условием, чтобы минимальная цена по тарифу бизнес (b.price) 
была меньше, чем максимальная цена по тарифу эконом (e.price).
В столбце ans собираем информацию по рейсам: идентификатор, город и аэропорт
отправления и назначения. Полученный результат сохраняем в CTE comparison.
Создаем подзапрос ‘t’, который при условии существования хотя бы одной строки 
в comparison будет выдавать 1, в противном случае 0. Объединяем comparison 
через left join с подзапросом  ‘t’ при условии t.case > 0, т.е. только в том 
случае, когда в comparison есть хотя бы одна строка. Через case создаем условие
выдачи результата: в случае, когда в comparison нет ни одной строки, получаем 
ответ “Не было”, в противном случае получаем столбец ans из comparison.

with comparison as
(select  f.flight_id,
		 e.price as economy,
		 b.price as business,
		 concat('flight_id №', f.flight_id::text, ' - рейс в г. ', 
		 	arrival.city, ' (', arrival.airport_code, ')',
		 	' из г. ', departure.city, ' (', departure.airport_code, ')') as ans
from 	 flights f
		 inner join (
		 			select 	 flight_id, max(amount) as price
					from 	 ticket_flights
					where 	 fare_conditions = 'Economy'
					group by flight_id
					) e on f.flight_id = e.flight_id
		 inner join (
					select flight_id, min(amount) as price
					from ticket_flights
					where fare_conditions = 'Business'
					group by flight_id
					) b on f.flight_id = b.flight_id
		 inner join airports departure on f.departure_airport = departure.airport_code
		 inner join airports arrival on f.arrival_airport = arrival.airport_code
where 	 b.price < e.price)
select 	 case 
		 	when t.case = 0 then 'Не было'
		 	else ans
	     end
from 	 ( 
	 	 select
		 case 
			when exists(select * from comparison) then 1 
			else 0
		 end
		 ) t
		 left join comparison on t.case > 0

8. Между какими городами нет прямых рейсов?

Логика: Для того, чтобы подтянуть названия городов (city) отправления и 
назначения дважды соединяем таблицу flights с таблицей airports, присваивая 
разные алиасы.
Для получения уникальных значений делаем группировку по городу отправления и 
городу назначения.
В результате получаем города, между которыми существуют прямые рейсы,
полученный результат сохраняем в материализованное представление routes_cities.
Для получения всех возможных сочетаний городов друг с другом делаем 
cross join таблицы airports с ней самой.
При помощи условия where a1.city < a2.city избавляемся от «зеркальных» 
сочетаний городов.
Исключаем города, между которыми есть прямые рейсы (except строки из 
routes_cities).

create materialized view routes_cities as
	select   departure.city as dep_city,
		 	 arrival.city as arv_city
	from 	 flights f
			 inner join airports departure on f.departure_airport = departure.airport_code
			 inner join airports arrival on f.arrival_airport = arrival.airport_code
	group by departure.city, arrival.city
with data

select  a1.city,
		a2.city 
from 	airports a1
		cross join airports a2
where 	a1.city < a2.city
except
select 	dep_city,
		arv_city
from 	routes_cities

9. Вычислите расстояние между аэропортами, связанными прямыми рейсами, 
сравните с допустимой максимальной дальностью перелетов  в самолетах, 
обслуживающих эти рейсы.

Логика: Делаем выборку по номеру рейса из таблицы flights, при помощи 
inner join подтягиваем  из таблицы aircrafts максимальную дальность полета.
Дважды соединяя с таблицей airports и присваивая разные алиасы, подтягиваем 
название аэропорта, город, долготу и широту для аэропортов отправления и 
назначения. Группируем по номеру рейса, коду самолета, коду аэропорта 
отправления и коду аэропорта прибытия, чтобы получить уникальные значения. 
Полученные данные записываем в материализованное представление 
routes_coordinates.
В CTE comparison, используя данные из представления routes_coordinates, 
вычисляем кратчайшее расстояние между городами (actual_distance) по формуле
длины ортодромии.
Далее в запросе сравниваем это расстояние с максимальной дальностью полета 
(max_distance).

create materialized view routes_coordinates as
select 	 f.flight_no,
		 a."range" as max_distance,
		 departure.airport_code as dep_airport_code,
		 departure.airport_name as dep_airport_name,
		 departure.city as dep_city,
		 departure.latitude as dep_latitude,
		 departure.longitude as dep_longitude, 
		 arrival.airport_code as arv_airport_code,
		 arrival.airport_name as arv_airport_name,
		 arrival.city as arv_city,
		 arrival.latitude as arv_latitude,
		 arrival.longitude as arv_longitude
from 	 flights f
		 inner join aircrafts a on f.aircraft_code = a.aircraft_code
		 inner join airports departure on f.departure_airport = departure.airport_code
		 inner join airports arrival on f.arrival_airport = arrival.airport_code
group by f.flight_no,
		 a.aircraft_code,
		 departure.airport_code,
		 arrival.airport_code
with data

with comparison as
(select flight_no,
		concat(dep_city, ' (', dep_airport_code, ')') as departure,
		concat(arv_city, ' (', arv_airport_code, ')') as arrival,
		max_distance,
		ceil(acos(sind(dep_latitude) * sind(arv_latitude) + 
			cosd(dep_latitude) * cosd(arv_latitude) * cosd(dep_longitude - arv_longitude)
			) * 6371) as actual_distance
from 	routes_coordinates)
select 	*
from 	comparison
where 	actual_distance >= max_distance
