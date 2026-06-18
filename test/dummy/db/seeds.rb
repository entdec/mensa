def random_role
  User.ROLES.sample
end

def set_customer_metrics(customer, number_of_employees:, market_cap:)
  customer.update!(number_of_employees:, market_cap:)
end

ADDITIONAL_USER_FIRST_NAMES = %w[Alex Jamie Taylor Morgan Casey Riley Jordan Sam Robin Avery].freeze
ADDITIONAL_USER_LAST_NAMES = %w[Jansen Smith Müller Garcia Rossi Dubois Brown Novak Silva Meier].freeze

# Adds a small, random number of extra users for a customer. The generated email
# addresses are stable per customer/slot, so re-running seeds remains idempotent.
def add_random_users_for(customer, max: 4)
  rand(0..max).times do |index|
    first_name = ADDITIONAL_USER_FIRST_NAMES.sample
    last_name = ADDITIONAL_USER_LAST_NAMES.sample

    User.find_or_create_by!(email: "seed.user.#{index + 1}@#{customer.name.parameterize}.example") do |user|
      user.first_name = first_name
      user.last_name = last_name
      user.role = random_role
      user.customer = customer
    end
  end
end

asml = Customer.find_or_create_by!(name: "ASML") do |c|
  c.stock_symbol = "ASML"
  c.country = "NL"
  c.isin = "NL0010273215"
  c.industry = "Semiconductor Equipment"
end
set_customer_metrics(asml, number_of_employees: 42_000, market_cap: 265_000_000_000)
User.find_or_create_by!(email: "peter.wennink@asml.com") do |user|
  user.first_name = "Peter"
  user.last_name = "Wennink"
  user.role = random_role
  user.customer = asml
end

sap = Customer.find_or_create_by!(name: "SAP") do |c|
  c.stock_symbol = "SAP"
  c.country = "DE"
  c.isin = "DE0007164600"
  c.industry = "Enterprise Software"
end
set_customer_metrics(sap, number_of_employees: 107_000, market_cap: 235_000_000_000)
User.find_or_create_by!(email: "christian.klein@sap.com") do |user|
  user.first_name = "Christian"
  user.last_name = "Klein"
  user.role = random_role
  user.customer = sap
end

ahold = Customer.find_or_create_by!(name: "Ahold Delhaize") do |c|
  c.stock_symbol = "AD"
  c.country = "NL"
  c.isin = "NL0011794037"
  c.industry = "Retail"
end
set_customer_metrics(ahold, number_of_employees: 414_000, market_cap: 31_000_000_000)
User.find_or_create_by!(email: "frans.muller@aholddelhaize.com") do |user|
  user.first_name = "Frans"
  user.last_name = "Muller"
  user.role = random_role
  user.customer = ahold
end

philips = Customer.find_or_create_by!(name: "Philips") do |c|
  c.stock_symbol = "PHIA"
  c.country = "NL"
  c.isin = "NL0000009538"
  c.industry = "Healthcare Technology"
end
set_customer_metrics(philips, number_of_employees: 69_000, market_cap: 17_000_000_000)
User.find_or_create_by!(email: "roy.jakobs@philips.com") do |user|
  user.first_name = "Roy"
  user.last_name = "Jakobs"
  user.role = random_role
  user.customer = philips
end

esa = Customer.find_or_create_by!(name: "ESA") do |c|
  c.stock_symbol = nil
  c.country = "FR"
  c.isin = nil
  c.industry = "Space Agency"
end
set_customer_metrics(esa, number_of_employees: 2_400, market_cap: 18_000_000_000)
User.find_or_create_by!(email: "josef.aschbacher@esa.int") do |user|
  user.first_name = "Josef"
  user.last_name = "Aschbacher"
  user.role = random_role
  user.customer = esa
end

rheinmetall = Customer.find_or_create_by!(name: "Rheinmetall") do |c|
  c.stock_symbol = "RHM"
  c.country = "DE"
  c.isin = "DE0007030009"
  c.industry = "Defense"
end
set_customer_metrics(rheinmetall, number_of_employees: 31_000, market_cap: 28_000_000_000)
User.find_or_create_by!(email: "armin.papperger@rheinmetall.com") do |user|
  user.first_name = "Armin"
  user.last_name = "Papperger"
  user.role = random_role
  user.customer = rheinmetall
end

airbus = Customer.find_or_create_by!(name: "Airbus") do |c|
  c.stock_symbol = "AIR"
  c.country = "FR"
  c.isin = "NL0000235190"
  c.industry = "Aerospace & Defense"
end
set_customer_metrics(airbus, number_of_employees: 148_000, market_cap: 125_000_000_000)
User.find_or_create_by!(email: "guillaume.faury@airbus.com") do |user|
  user.first_name = "Guillaume"
  user.last_name = "Faury"
  user.role = random_role
  user.customer = airbus
end

vw = Customer.find_or_create_by!(name: "VW") do |c|
  c.stock_symbol = "VOW3"
  c.country = "DE"
  c.isin = "DE0007664039"
  c.industry = "Automotive"
end
set_customer_metrics(vw, number_of_employees: 684_000, market_cap: 64_000_000_000)
User.find_or_create_by!(email: "herbert@vw.de") do |user|
  user.first_name = "Herbert"
  user.last_name = "Diess"
  user.role = random_role
  user.customer = vw
end

bmw = Customer.find_or_create_by!(name: "BMW") do |c|
  c.stock_symbol = "BMW"
  c.country = "DE"
  c.isin = "DE0005190003"
  c.industry = "Automotive"
end
set_customer_metrics(bmw, number_of_employees: 155_000, market_cap: 72_000_000_000)
User.find_or_create_by!(email: "oliver.zipse@bmw.com") do |user|
  user.first_name = "Oliver"
  user.last_name = "Zipse"
  user.role = random_role
  user.customer = bmw
end

mercedes = Customer.find_or_create_by!(name: "Mercedes") do |c|
  c.stock_symbol = "MBG"
  c.country = "DE"
  c.isin = "DE0007100000"
  c.industry = "Automotive"
end
set_customer_metrics(mercedes, number_of_employees: 166_000, market_cap: 78_000_000_000)
User.find_or_create_by!(email: "ola.kallenius@mercedes-benz.com") do |user|
  user.first_name = "Ola"
  user.last_name = "Källenius"
  user.role = random_role
  user.customer = mercedes
end

audi = Customer.find_or_create_by!(name: "Audi") do |c|
  c.stock_symbol = nil
  c.country = "DE"
  c.isin = nil
  c.industry = "Automotive"
end
set_customer_metrics(audi, number_of_employees: 88_000, market_cap: 58_000_000_000)
User.find_or_create_by!(email: "gernot.doellner@audi.de") do |user|
  user.first_name = "Gernot"
  user.last_name = "Döllner"
  user.role = random_role
  user.customer = audi
end

porsche = Customer.find_or_create_by!(name: "Porsche") do |c|
  c.stock_symbol = "P911"
  c.country = "DE"
  c.isin = "DE000PAG9113"
  c.industry = "Automotive"
end
set_customer_metrics(porsche, number_of_employees: 42_000, market_cap: 95_000_000_000)
User.find_or_create_by!(email: "oliver.blume@porsche.de") do |user|
  user.first_name = "Oliver"
  user.last_name = "Blume"
  user.role = random_role
  user.customer = porsche
end

ferrari = Customer.find_or_create_by!(name: "Ferrari") do |c|
  c.stock_symbol = "RACE"
  c.country = "IT"
  c.isin = "NL0011585146"
  c.industry = "Automotive"
end
set_customer_metrics(ferrari, number_of_employees: 5_000, market_cap: 78_000_000_000)
User.find_or_create_by!(email: "benedetto.vigna@ferrari.com") do |user|
  user.first_name = "Benedetto"
  user.last_name = "Vigna"
  user.role = random_role
  user.customer = ferrari
end

shell = Customer.find_or_create_by!(name: "Shell") do |c|
  c.stock_symbol = "SHEL"
  c.country = "GB"
  c.isin = "GB00BP6MXD84"
  c.industry = "Oil & Gas"
end
set_customer_metrics(shell, number_of_employees: 103_000, market_cap: 205_000_000_000)
User.find_or_create_by!(email: "wael.sawan@shell.com") do |user|
  user.first_name = "Wael"
  user.last_name = "Sawan"
  user.role = random_role
  user.customer = shell
end

siemens = Customer.find_or_create_by!(name: "Siemens") do |c|
  c.stock_symbol = "SIE"
  c.country = "DE"
  c.isin = "DE0007236101"
  c.industry = "Industrials"
end
set_customer_metrics(siemens, number_of_employees: 320_000, market_cap: 145_000_000_000)
User.find_or_create_by!(email: "roland.busch@siemens.com") do |user|
  user.first_name = "Roland"
  user.last_name = "Busch"
  user.role = random_role
  user.customer = siemens
end

nestle = Customer.find_or_create_by!(name: "Nestlé") do |c|
  c.stock_symbol = "NESN"
  c.country = "CH"
  c.isin = "CH0038863350"
  c.industry = "Food & Beverage"
end
set_customer_metrics(nestle, number_of_employees: 270_000, market_cap: 285_000_000_000)
User.find_or_create_by!(email: "mark.schneider@nestle.com") do |user|
  user.first_name = "Mark"
  user.last_name = "Schneider"
  user.role = random_role
  user.customer = nestle
end

unilever = Customer.find_or_create_by!(name: "Unilever") do |c|
  c.stock_symbol = "ULVR"
  c.country = "GB"
  c.isin = "GB00B10RZP78"
  c.industry = "Consumer Goods"
end
set_customer_metrics(unilever, number_of_employees: 128_000, market_cap: 118_000_000_000)
User.find_or_create_by!(email: "hein.schumacher@unilever.com") do |user|
  user.first_name = "Hein"
  user.last_name = "Schumacher"
  user.role = random_role
  user.customer = unilever
end

total = Customer.find_or_create_by!(name: "TotalEnergies") do |c|
  c.stock_symbol = "TTE"
  c.country = "FR"
  c.isin = "FR0000120271"
  c.industry = "Oil & Gas"
end
set_customer_metrics(total, number_of_employees: 102_000, market_cap: 160_000_000_000)
User.find_or_create_by!(email: "patrick.pouyanne@total.com") do |user|
  user.first_name = "Patrick"
  user.last_name = "Pouyanné"
  user.role = random_role
  user.customer = total
end

bp = Customer.find_or_create_by!(name: "BP") do |c|
  c.stock_symbol = "BP"
  c.country = "GB"
  c.isin = "GB0007980591"
  c.industry = "Oil & Gas"
end
set_customer_metrics(bp, number_of_employees: 87_000, market_cap: 92_000_000_000)
User.find_or_create_by!(email: "murray.auchincloss@bp.com") do |user|
  user.first_name = "Murray"
  user.last_name = "Auchincloss"
  user.role = random_role
  user.customer = bp
end

glencore = Customer.find_or_create_by!(name: "Glencore") do |c|
  c.stock_symbol = "GLEN"
  c.country = "CH"
  c.isin = "JE00B4T3BW64"
  c.industry = "Mining & Commodities"
end
set_customer_metrics(glencore, number_of_employees: 145_000, market_cap: 70_000_000_000)
User.find_or_create_by!(email: "gary.nagle@glencore.com") do |user|
  user.first_name = "Gary"
  user.last_name = "Nagle"
  user.role = random_role
  user.customer = glencore
end

enel = Customer.find_or_create_by!(name: "Enel") do |c|
  c.stock_symbol = "ENEL"
  c.country = "IT"
  c.isin = "IT0003128367"
  c.industry = "Utilities"
end
set_customer_metrics(enel, number_of_employees: 61_000, market_cap: 72_000_000_000)
User.find_or_create_by!(email: "flavio.cattaneo@enel.com") do |user|
  user.first_name = "Flavio"
  user.last_name = "Cattaneo"
  user.role = random_role
  user.customer = enel
end

vodafone = Customer.find_or_create_by!(name: "Vodafone") do |c|
  c.stock_symbol = "VOD"
  c.country = "GB"
  c.isin = "GB00BH4HKS39"
  c.industry = "Telecommunications"
end
set_customer_metrics(vodafone, number_of_employees: 94_000, market_cap: 24_000_000_000)
User.find_or_create_by!(email: "margherita.della.valle@vodafone.com") do |user|
  user.first_name = "Margherita"
  user.last_name = "Della Valle"
  user.role = random_role
  user.customer = vodafone
end

loreal = Customer.find_or_create_by!(name: "L'Oréal") do |c|
  c.stock_symbol = "OR"
  c.country = "FR"
  c.isin = "FR0000120321"
  c.industry = "Cosmetics"
end
set_customer_metrics(loreal, number_of_employees: 90_000, market_cap: 235_000_000_000)
User.find_or_create_by!(email: "nicolas.hieronimus@loreal.com") do |user|
  user.first_name = "Nicolas"
  user.last_name = "Hieronimus"
  user.role = random_role
  user.customer = loreal
end

axa = Customer.find_or_create_by!(name: "AXA") do |c|
  c.stock_symbol = "CS"
  c.country = "FR"
  c.isin = "FR0000120628"
  c.industry = "Insurance"
end
set_customer_metrics(axa, number_of_employees: 147_000, market_cap: 85_000_000_000)
User.find_or_create_by!(email: "thomas.buberl@axa.com") do |user|
  user.first_name = "Thomas"
  user.last_name = "Buberl"
  user.role = random_role
  user.customer = axa
end

credit_agricole = Customer.find_or_create_by!(name: "Crédit Agricole") do |c|
  c.stock_symbol = "ACA"
  c.country = "FR"
  c.isin = "FR0000045072"
  c.industry = "Banking"
end
set_customer_metrics(credit_agricole, number_of_employees: 154_000, market_cap: 42_000_000_000)
User.find_or_create_by!(email: "philippe.brasac@credit-agricole.com") do |user|
  user.first_name = "Philippe"
  user.last_name = "Brassac"
  user.role = random_role
  user.customer = credit_agricole
end

barclays = Customer.find_or_create_by!(name: "Barclays") do |c|
  c.stock_symbol = "BARC"
  c.country = "GB"
  c.isin = "GB0031348658"
  c.industry = "Banking"
end
set_customer_metrics(barclays, number_of_employees: 92_000, market_cap: 32_000_000_000)
User.find_or_create_by!(email: "cs.venkatakrishnan@barclays.com") do |user|
  user.first_name = "C.S."
  user.last_name = "Venkatakrishnan"
  user.role = random_role
  user.customer = barclays
end

santander = Customer.find_or_create_by!(name: "Banco Santander") do |c|
  c.stock_symbol = "SAN"
  c.country = "ES"
  c.isin = "ES0113900J37"
  c.industry = "Banking"
end
set_customer_metrics(santander, number_of_employees: 206_000, market_cap: 96_000_000_000)
User.find_or_create_by!(email: "ana.botin@santander.com") do |user|
  user.first_name = "Ana"
  user.last_name = "Botín"
  user.role = random_role
  user.customer = santander
end

intesa = Customer.find_or_create_by!(name: "Intesa Sanpaolo") do |c|
  c.stock_symbol = "ISP"
  c.country = "IT"
  c.isin = "IT0000072618"
  c.industry = "Banking"
end
set_customer_metrics(intesa, number_of_employees: 95_000, market_cap: 82_000_000_000)
User.find_or_create_by!(email: "carlo.messina@intesasanpaolo.com") do |user|
  user.first_name = "Carlo"
  user.last_name = "Messina"
  user.role = random_role
  user.customer = intesa
end

volvo = Customer.find_or_create_by!(name: "Volvo") do |c|
  c.stock_symbol = "VOLV-B"
  c.country = "SE"
  c.isin = "SE0000115446"
  c.industry = "Automotive"
end
set_customer_metrics(volvo, number_of_employees: 104_000, market_cap: 42_000_000_000)
User.find_or_create_by!(email: "martin.lundstedt@volvo.com") do |user|
  user.first_name = "Martin"
  user.last_name = "Lundstedt"
  user.role = random_role
  user.customer = volvo
end

ericsson = Customer.find_or_create_by!(name: "Ericsson") do |c|
  c.stock_symbol = "ERIC-B"
  c.country = "SE"
  c.isin = "SE0000108656"
  c.industry = "Telecommunications"
end
set_customer_metrics(ericsson, number_of_employees: 95_000, market_cap: 18_000_000_000)
User.find_or_create_by!(email: "borje.ekholm@ericsson.com") do |user|
  user.first_name = "Börje"
  user.last_name = "Ekholm"
  user.role = random_role
  user.customer = ericsson
end

adecco = Customer.find_or_create_by!(name: "Adecco") do |c|
  c.stock_symbol = "ADEN"
  c.country = "CH"
  c.isin = "CH0012138605"
  c.industry = "Staffing"
end
set_customer_metrics(adecco, number_of_employees: 33_000, market_cap: 6_000_000_000)
User.find_or_create_by!(email: "denis.machuel@adeccogroup.com") do |user|
  user.first_name = "Denis"
  user.last_name = "Machuel"
  user.role = random_role
  user.customer = adecco
end

danone = Customer.find_or_create_by!(name: "Danone") do |c|
  c.stock_symbol = "BN"
  c.country = "FR"
  c.isin = "FR0000120644"
  c.industry = "Food & Beverage"
end
set_customer_metrics(danone, number_of_employees: 89_000, market_cap: 44_000_000_000)
User.find_or_create_by!(email: "antoine.de-saint-affrique@danone.com") do |user|
  user.first_name = "Antoine"
  user.last_name = "de Saint-Affrique"
  user.role = random_role
  user.customer = danone
end

heineken = Customer.find_or_create_by!(name: "Heineken") do |c|
  c.stock_symbol = "HEIA"
  c.country = "NL"
  c.isin = "NL0000009165"
  c.industry = "Beverages"
end
set_customer_metrics(heineken, number_of_employees: 85_000, market_cap: 52_000_000_000)
User.find_or_create_by!(email: "dolf.vandenbrink@heineken.com") do |user|
  user.first_name = "Dolf"
  user.last_name = "van den Brink"
  user.role = random_role
  user.customer = heineken
end

carlsberg = Customer.find_or_create_by!(name: "Carlsberg") do |c|
  c.stock_symbol = "CARL-B"
  c.country = "DK"
  c.isin = "DK0010181676"
  c.industry = "Beverages"
end
set_customer_metrics(carlsberg, number_of_employees: 32_000, market_cap: 16_000_000_000)
User.find_or_create_by!(email: "jacob.aarup-andersen@carlsberg.com") do |user|
  user.first_name = "Jacob"
  user.last_name = "Aarup-Andersen"
  user.role = random_role
  user.customer = carlsberg
end

Customer.find_each do |customer|
  add_random_users_for(customer, max: 4)
end

Mensa::TableView.find_or_create_by!(table_name: "users", name: "Admins") do |table|
  table.config = {filters: {role: {value: "admin"}}}
end
Mensa::TableView.find_or_create_by!(table_name: "users", name: "Guests") do |table|
  table.config = {filters: {role: {value: "guest"}}}
end
Mensa::TableView.find_or_create_by!(table_name: "users", name: "Users") do |table|
  table.config = {filters: {role: {value: "user"}}}
end

Mensa::TableView.find_or_create_by!(table_name: "customers", name: "Dutch") do |table|
  table.config = {filters: {country: {value: "NL"}}}
end

Mensa::TableView.find_or_create_by!(table_name: "customers", name: "German") do |table|
  table.description = "Customers from Germany"
  table.config = {filters: {country: {value: "DE"}}}
end
