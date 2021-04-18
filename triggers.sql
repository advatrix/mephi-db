create or replace function check_pricelist_category() returns trigger as $check_pricelist_category$
begin 
	if not (
		select c.pricelist_category_id = pl.category_id
		from "customer" c 
		join "pricelist" pl on new.pricelist_id = pl.id 
		where c.id = new.customer_id
	) then
		raise exception 'pricelist category id mismatch';
	end if;
	return null;
end;
$check_pricelist_category$ language plpgsql;

create trigger check_pricelist_category
after insert or update on consignment_note
for each row execute function check_pricelist_category();

create or replace function consignment_note_item_reserve() returns trigger as $consignment_note_item_reserve$
declare 
	goods_available integer;
begin
	select g.quantity into goods_available
	from "good" g
	where g.id = new.good_id;
	if new.ordered <= goods_available then 
		new.reserved := new.ordered;
	else new.reserved := goods_available;
	end if;
	return new;
end;
$consignment_note_item_reserve$ language plpgsql;

create trigger consignment_note_item_reserve
before insert or update on consignment_note_item
for each row execute function consignment_note_item_reserve();

create or replace function update_good_quantity() returns trigger as $update_good_quantity$
begin
	update "good"
	set quantity = quantity - new.reserved
	where id = new.good_id;
	return null;
end;
$update_good_quantity$ language plpgsql;

create trigger update_good_quantity
after insert or update on consignment_note_item
for each row execute function update_good_quantity();

