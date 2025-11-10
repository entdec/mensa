def random_role
  User.ROLES.sample
end

asml = Customer.find_or_create_by!(name: "ASML") do |c|
  c.stock_symbol = "ASML"
  c.country = "NL"
  c.isin = "NL0010273215"
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
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
end
User.find_or_create_by!(email: "jacob.aarup-andersen@carlsberg.com") do |user|
  user.first_name = "Jacob"
  user.last_name = "Aarup-Andersen"
  user.role = random_role
  user.customer = carlsberg
end

Mensa::TableView.find_or_create_by!(table_name: "users", name: "Admins") do |table|
   table.data= {filters: {role: "admin"}}
end
Mensa::TableView.find_or_create_by!(table_name: "users", name: "Guests") do |table|
   table.data= {filters: {role: "guest"}}
end
Mensa::TableView.find_or_create_by!(table_name: "users", name: "Users") do |table|
   table.data= {filters: {role: "user"}}
end

Mensa::TableView.find_or_create_by!(table_name: "customers", name: "Dutch") do |table|
   table.data= {filters: {country: "NL"}}
end

Mensa::TableView.find_or_create_by!(table_name: "customers", name: "German") do |table|
   table.data= {filters: {country: "DE"}}
end
