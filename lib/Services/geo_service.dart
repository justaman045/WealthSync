import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:money_control/Platform/geocoding_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Returns the estimated average monthly income (₹) for the user's location,
/// used as the expense baseline when no transaction history exists.
///
/// Values are derived from NSSO/CMIE urban salaried-worker income data,
/// adjusted to represent the typical Money Control user demographic
/// (smartphone-owning, finance-app-using urban/semi-urban salaried worker).
///
/// Lookup priority: sub-locality keyword → city → district → state → national median
class GeoService {
  static const _keyCity        = 'geo_city';
  static const _keySubLocality = 'geo_sub_locality';
  static const _keyDistrict    = 'geo_district';
  static const _keyState       = 'geo_state';
  static const _keyIncome      = 'geo_income';
  static const _keyTimestamp   = 'geo_timestamp';
  static const _cacheTtlHours  = 6;

  /// National median for an urban salaried app user (₹/month).
  static const int _nationalMedian = 25000;

  // ── Sub-locality Zone A keywords → ultra-premium income bracket ──────────
  // These micro-markets attract disproportionately high earners.
  static const _zoneAKeywords = [
    'dlf phase', 'dlf city', 'golf course road', 'golf course ext',
    'sector 42', 'sector 53', 'sector 54', 'sector 55', 'sector 56',
    'sector 44', 'sector 45', 'sector 46', 'sector 47', 'sector 48',
    'sector 49', 'sector 50', 'sushant lok', 'palam vihar',
    'malabar hill', 'altamount', 'carmichael', 'breach candy',
    'worli sea face', 'bandra west', 'juhu', 'pali hill',
    'lutyens', 'golf links', 'jor bagh', 'sundar nagar',
    'vasant vihar', 'defence colony', 'greater kailash',
    'koramangala', 'indiranagar', 'hsr layout', 'richmond',
    'jubilee hills', 'banjara hills',
    'koregaon park', 'kalyani nagar',
    'nungambakkam', 'adyar', 'boat club', 'poes garden',
  ];
  static const int _zoneAIncome = 80000;

  // ── City → estimated average monthly income (₹) ──────────────────────────
  // ~550 cities. Values represent urban salaried median for that city.
  static const Map<String, int> _cityIncome = {
    // ── Mega metros ──────────────────────────────────────────────────────────
    'mumbai': 55000, 'navi mumbai': 42000, 'thane': 38000,
    'kalyan': 30000, 'dombivli': 30000, 'ulhasnagar': 26000,
    'vasai': 28000, 'virar': 26000, 'mira road': 30000,
    'bhiwandi': 24000, 'palghar': 24000, 'mira-bhayandar': 30000,
    'new delhi': 55000, 'delhi': 55000,
    'gurugram': 70000, 'gurgaon': 70000,
    'noida': 50000, 'greater noida': 45000,
    'faridabad': 35000, 'ghaziabad': 32000,
    'bengaluru': 60000, 'bangalore': 60000,
    'hyderabad': 55000, 'secunderabad': 50000, 'cyberabad': 60000,
    'pune': 50000, 'pimpri-chinchwad': 38000, 'pimpri': 35000, 'chinchwad': 35000,
    'chennai': 48000,
    'kolkata': 35000, 'howrah': 28000,
    'ahmedabad': 36000, 'gandhinagar': 38000,
    'chandigarh': 42000, 'mohali': 40000, 'sahibzada ajit singh nagar': 40000,
    'panchkula': 38000,
    'surat': 34000,
    // ── Tier-1B ──────────────────────────────────────────────────────────────
    'kochi': 38000, 'ernakulam': 38000, 'cochin': 38000,
    'jaipur': 30000,
    'lucknow': 30000,
    'nagpur': 30000,
    'indore': 30000,
    'bhopal': 28000,
    'coimbatore': 30000,
    'visakhapatnam': 28000, 'vizag': 28000,
    'bhubaneswar': 28000,
    'thiruvananthapuram': 28000, 'trivandrum': 28000,
    'vadodara': 28000, 'baroda': 28000,
    'nashik': 26000,
    'rajkot': 26000,
    'dehradun': 28000,
    'mysuru': 26000, 'mysore': 26000,
    'mangaluru': 26000, 'mangalore': 26000,
    'kozhikode': 26000, 'calicut': 26000,
    'thrissur': 26000,
    'warangal': 24000, 'hanamkonda': 24000,
    'vijayawada': 26000,
    'tiruppur': 24000,
    'panaji': 36000, 'panjim': 36000,
    'margao': 30000, 'vasco da gama': 28000, 'mapusa': 28000,
    // ── Tier-2 ───────────────────────────────────────────────────────────────
    'agra': 22000, 'mathura': 22000, 'vrindavan': 20000,
    'meerut': 22000,
    'varanasi': 22000, 'banaras': 22000,
    'patna': 24000,
    'ludhiana': 26000,
    'amritsar': 24000,
    'guwahati': 24000, 'dispur': 24000,
    'srinagar': 24000,
    'jammu': 22000,
    'jodhpur': 22000,
    'kota': 22000,
    'udaipur': 22000,
    'ajmer': 20000,
    'jabalpur': 22000,
    'gwalior': 22000,
    'raipur': 24000,
    'bhilai': 24000, 'durg': 22000,
    'cuttack': 22000,
    'kolhapur': 24000,
    'aurangabad': 24000, 'chhatrapati sambhajinagar': 24000,
    'solapur': 22000,
    'amravati': 20000,
    'puri': 20000,
    'haridwar': 22000, 'rishikesh': 22000,
    'haldwani': 22000,
    'roorkee': 24000,
    'gangtok': 24000,
    'shillong': 22000,
    'agartala': 20000,
    'imphal': 18000,
    'aizawl': 20000,
    'kohima': 20000,
    'itanagar': 20000, 'naharlagun': 18000,
    'darjeeling': 22000,
    'siliguri': 22000,
    'durgapur': 22000,
    'asansol': 20000,
    'rourkela': 22000,
    'jamshedpur': 26000,
    'dhanbad': 22000,
    'bokaro': 22000, 'bokaro steel city': 22000,
    'ranchi': 24000,
    'tirupati': 24000,
    'vijayapura': 18000, 'bijapur': 18000,
    'hubli': 20000, 'dharwad': 20000, 'hubballi': 20000,
    'belagavi': 20000, 'belgaum': 20000,
    'kalaburagi': 18000, 'gulbarga': 18000,
    'ballari': 18000, 'bellary': 18000,
    'tumakuru': 20000, 'tumkur': 20000,
    'davanagere': 18000,
    'shivamogga': 20000, 'shimoga': 20000,
    'udupi': 22000,
    'hassan': 18000,
    'madurai': 20000,
    'tiruchirappalli': 20000, 'trichy': 20000,
    'salem': 20000,
    'tirunelveli': 18000,
    'erode': 20000,
    'vellore': 20000,
    'thoothukudi': 18000, 'tuticorin': 18000,
    'thanjavur': 18000,
    'rajahmundry': 20000, 'rajamahendravaram': 20000,
    'nellore': 20000,
    'guntur': 20000,
    'kakinada': 18000,
    'kadapa': 18000, 'cuddapah': 18000,
    'kurnool': 18000,
    'anantapur': 16000,
    'nizamabad': 18000,
    'karimnagar': 18000,
    'khammam': 18000,
    // ── Tier-2 continued ─────────────────────────────────────────────────────
    'patiala': 26000,
    'bathinda': 22000,
    'jalandhar': 24000,
    'ambala': 26000,
    'rohtak': 24000,
    'hisar': 22000,
    'panipat': 24000,
    'karnal': 24000,
    'sonipat': 26000,
    'rewari': 26000,
    'yamunanagar': 22000,
    'bhiwani': 20000,
    'jind': 20000,
    'kaithal': 20000,
    'kurukshetra': 22000,
    'sirsa': 20000,
    'shimla': 26000,
    'dharamsala': 24000, 'dharamshala': 24000,
    'solan': 24000,
    'mandi': 20000,
    'kangra': 20000,
    'kullu': 22000, 'manali': 24000,
    'bilaspur': 20000,
    'hamirpur': 18000,
    'una': 18000,
    'kashipur': 22000,
    'rudrapur': 24000,
    'nainital': 22000, 'mussoorie': 22000,
    'bareilly': 20000,
    'moradabad': 20000,
    'saharanpur': 18000,
    'gorakhpur': 18000,
    'aligarh': 18000,
    'firozabad': 16000,
    'muzaffarnagar': 18000,
    'jhansi': 18000,
    'hapur': 20000,
    'bulandshahr': 18000,
    'shahjahanpur': 16000,
    'rampur': 16000,
    'ayodhya': 18000, 'faizabad': 18000,
    'bijnor': 16000,
    'amroha': 16000,
    'sambhal': 16000,
    'shamli': 18000,
    'baghpat': 18000,
    'kanpur': 20000, 'kanpur nagar': 20000,
    'prayagraj': 18000, 'allahabad': 18000,
    'jaunpur': 14000,
    'azamgarh': 14000,
    'ballia': 13000,
    'ghazipur': 14000,
    'etawah': 14000,
    'mainpuri': 14000,
    'farrukhabad': 14000, 'fatehgarh': 14000,
    'kannauj': 14000,
    'rae bareli': 14000, 'raebareli': 14000,
    'unnao': 16000,
    'barabanki': 16000,
    'sultanpur': 13000,
    'lakhimpur': 13000, 'lakhimpur kheri': 13000,
    'sitapur': 13000,
    'hardoi': 13000,
    'banda': 12000,
    'mahoba': 12000,
    'lalitpur': 12000,
    'jalaun': 12000, 'orai': 12000,
    'basti': 13000,
    'sant kabir nagar': 12000,
    'siddharthnagar': 12000,
    'maharajganj': 12000,
    'kushinagar': 13000,
    'deoria': 13000,
    'mau': 13000,
    'ambedkar nagar': 13000,
    'amethi': 13000,
    'fatehpur': 13000,
    'kaushambi': 13000,
    'gonda': 13000,
    'bahraich': 12000,
    'shravasti': 11000,
    'balrampur': 11000,
    'etah': 13000,
    'kasganj': 13000,
    'auraiya': 13000,
    'chitrakoot': 11000,
    'sonbhadra': 18000, 'renukoot': 18000,  // industrial wages from coal/power sector
    'mirzapur': 14000,
    'chandauli': 13000,
    'pratapgarh': 13000,
    // ── Bihar ─────────────────────────────────────────────────────────────────
    'gaya': 14000,
    'muzaffarpur': 14000,
    'bhagalpur': 14000,
    'darbhanga': 13000,
    'purnia': 13000, 'purnea': 13000,
    'ara': 12000, 'bhojpur': 12000,
    'munger': 13000,
    'begusarai': 13000,
    'samastipur': 12000,
    'siwan': 12000,
    'chapra': 12000,
    'nalanda': 12000, 'biharsharif': 12000,
    'nawada': 11000,
    'jehanabad': 11000,
    'arwal': 11000,
    'sasaram': 12000,
    'buxar': 12000,
    'bhabua': 11000,
    'sitamarhi': 11000,
    'sheohar': 10000,
    'madhubani': 11000,
    'supaul': 11000,
    'madhepura': 11000,
    'saharsa': 11000,
    'khagaria': 11000,
    'kishanganj': 12000,
    'araria': 11000,
    'katihar': 12000,
    'banka': 11000,
    'jamui': 11000,
    'lakhisarai': 11000,
    'sheikhpura': 11000,
    'bettiah': 11000,
    'motihari': 12000,
    'gopalganj': 12000,
    'hajipur': 12000,
    // ── Jharkhand ─────────────────────────────────────────────────────────────
    'hazaribagh': 18000,
    'deoghar': 16000,
    'giridih': 15000,
    'ramgarh': 16000,
    'chatra': 13000,
    'koderma': 14000,
    'lohardaga': 13000,
    'gumla': 12000,
    'simdega': 12000,
    'chaibasa': 15000,
    'saraikela': 14000,
    'khunti': 12000,
    'pakur': 12000,
    'godda': 12000,
    'sahibganj': 12000,
    'dumka': 13000,
    'jamtara': 12000,
    'latehar': 12000,
    'daltonganj': 14000,
    // ── Chhattisgarh ──────────────────────────────────────────────────────────
    'korba': 20000,  // industrial/power sector
    'raigarh': 16000,
    'ambikapur': 15000,
    'jagdalpur': 14000,
    'rajnandgaon': 14000,
    'dhamtari': 14000,
    'mahasamund': 13000,
    'kawardha': 12000,
    'kondagaon': 12000,
    'kanker': 12000,
    'jashpur': 12000,
    'narayanpur': 11000,
    'dantewada': 11000,
    'sukma': 10000,
    // ── Odisha ────────────────────────────────────────────────────────────────
    'berhampur': 18000, 'brahmapur': 18000,
    'sambalpur': 18000,
    'balasore': 16000, 'baleshwar': 16000,
    'baripada': 15000,
    'angul': 18000,  // industrial
    'dhenkanal': 15000,
    'keonjhar': 14000,
    'sundargarh': 16000,
    'jharsuguda': 18000,  // industrial
    'bargarh': 14000,
    'bolangir': 13000, 'balangir': 13000,
    'rayagada': 13000,
    'koraput': 13000,
    'malkangiri': 11000,
    'nabarangpur': 11000,
    'nuapada': 11000,
    'kalahandi': 11000,
    'kandhamal': 11000,
    'boudh': 11000,
    'sonepur': 11000,
    'nayagarh': 13000,
    'gajapati': 11000,
    'ganjam': 14000,
    'jagatsinghpur': 14000,
    'jajpur': 15000,
    'kendrapara': 13000,
    'khordha': 24000,  // Bhubaneswar suburbs
    'mayurbhanj': 13000,
    'kendujhar': 14000,
    // ── West Bengal ───────────────────────────────────────────────────────────
    'bardhaman': 20000, 'burdwan': 20000,
    'malda': 16000,
    'murshidabad': 15000,
    'krishnanagar': 18000,
    'barasat': 22000,
    'medinipur': 15000, 'midnapore': 15000,
    'bankura': 15000,
    'purulia': 14000,
    'birbhum': 15000,
    'cooch behar': 15000,
    'jalpaiguri': 16000,
    'alipurduar': 15000,
    'kalimpong': 18000,
    'jhargram': 13000,
    // ── Maharashtra ───────────────────────────────────────────────────────────
    'sangli': 22000,
    'satara': 20000,
    'ahmednagar': 20000, 'ahilyanagar': 20000,
    'latur': 16000,
    'osmanabad': 14000, 'dharashiv': 14000,
    'nanded': 16000,
    'hingoli': 13000,
    'parbhani': 14000,
    'jalna': 14000,
    'beed': 14000,
    'akola': 18000,
    'washim': 13000,
    'buldhana': 14000,
    'yavatmal': 14000,
    'wardha': 16000,
    'chandrapur': 18000,
    'gadchiroli': 11000,
    'gondia': 15000,
    'bhandara': 15000,
    'raigad': 26000,
    'ratnagiri': 20000,
    'sindhudurg': 18000,
    'dhule': 16000,
    'jalgaon': 18000,
    'nandurbar': 13000,
    // ── Karnataka ─────────────────────────────────────────────────────────────
    'mandya': 18000,
    'ramanagara': 18000,
    'chikkaballapur': 18000,
    'kolar': 18000,
    'bagalkot': 15000,
    'bidar': 15000,
    'raichur': 15000,
    'koppal': 14000,
    'gadag': 15000,
    'haveri': 15000,
    'karwar': 18000,
    'kodagu': 22000, 'coorg': 22000,
    'chamarajanagar': 14000,
    'chikkamagaluru': 20000,
    'chitradurga': 15000,
    'yadgir': 13000,
    'vijayanagara': 16000,
    // ── Tamil Nadu ────────────────────────────────────────────────────────────
    'dindigul': 16000,
    'ranipet': 18000,
    'sivaganga': 15000,
    'virudhunagar': 16000,
    'ramanathapuram': 14000,
    'krishnagiri': 16000,
    'dharmapuri': 14000,
    'namakkal': 16000,
    'ariyalur': 14000,
    'perambalur': 14000,
    'cuddalore': 16000,
    'nagapattinam': 14000,
    'tiruvarur': 14000,
    'mayiladuthurai': 14000, 'myladuthurai': 14000,
    'viluppuram': 14000,
    'kallakurichi': 14000,
    'tiruvannamalai': 15000,
    'kanchipuram': 22000,
    'chengalpattu': 28000,
    'tiruvallur': 26000,
    'pudukkottai': 14000,
    'ooty': 18000, 'udhagamandalam': 18000,
    'tenkasi': 14000,
    'tirupattur': 15000,
    // ── Telangana ─────────────────────────────────────────────────────────────
    'mahbubnagar': 16000, 'mahabubnagar': 16000,
    'nalgonda': 16000,
    'adilabad': 15000,
    'medchal': 38000,
    'rangareddy': 40000,
    'sangareddy': 22000,
    'siddipet': 16000,
    'jagitial': 15000,
    'peddapalli': 15000,
    'mancherial': 15000,
    'bhadradri kothagudem': 15000,
    'suryapet': 15000,
    'yadadri bhuvanagiri': 16000,
    'vikarabad': 16000,
    'wanaparthy': 14000,
    'nagarkurnool': 14000,
    'narayanpet': 13000,
    'mulugu': 12000,
    'jayashankar bhupalpally': 13000,
    'kumuram bheem': 12000,
    // ── Andhra Pradesh ────────────────────────────────────────────────────────
    'vizianagaram': 15000,
    'srikakulam': 14000,
    'chittoor': 16000,
    'nandyal': 15000,
    'ongole': 16000,
    'eluru': 16000,
    'machilipatnam': 16000,
    'bapatla': 14000,
    'parvathipuram': 13000,
    // ── Kerala ────────────────────────────────────────────────────────────────
    'kollam': 26000,
    'kannur': 26000,
    'alappuzha': 24000, 'alleppey': 24000,
    'palakkad': 22000,
    'malappuram': 22000,
    'kottayam': 24000,
    'idukki': 22000,
    'pathanamthitta': 24000,
    'wayanad': 20000,
    'kasaragod': 22000,
    // ── Gujarat ───────────────────────────────────────────────────────────────
    'bhavnagar': 24000,
    'jamnagar': 24000,
    'junagadh': 22000,
    'anand': 26000,
    'mehsana': 22000,
    'surendranagar': 18000,
    'amreli': 16000,
    'porbandar': 18000,
    'morbi': 20000,
    'botad': 16000,
    'aravalli': 15000,
    'mahisagar': 15000,
    'kheda': 20000,
    'patan': 16000,
    'banaskantha': 15000,
    'sabarkantha': 16000,
    'valsad': 24000,
    'navsari': 22000,
    'tapi': 14000,
    'dang': 11000,
    'narmada': 15000,
    'bharuch': 26000,
    'chhota udaipur': 13000,
    'dahod': 13000,
    'panchmahals': 16000, 'godhra': 16000,
    'gir somnath': 16000,
    'devbhoomi dwarka': 16000,
    // ── Rajasthan ─────────────────────────────────────────────────────────────
    'bikaner': 18000,
    'alwar': 18000,
    'bharatpur': 16000,
    'sikar': 16000,
    'sri ganganagar': 18000,
    'hanumangarh': 16000,
    'pali': 16000,
    'barmer': 14000,
    'nagaur': 14000,
    'chittorgarh': 16000,
    'bhilwara': 18000,
    'tonk': 15000,
    'sawai madhopur': 14000,
    'dausa': 14000,
    'bundi': 14000,
    'baran': 13000,
    'jhalawar': 13000,
    'dungarpur': 13000,
    'banswara': 13000,
    'rajsamand': 16000,
    'sirohi': 14000,
    'jalore': 13000,
    'jaisalmer': 13000,
    'jhunjhunu': 16000,
    'churu': 14000,
    'dholpur': 14000,
    'karauli': 13000,
    // ── Madhya Pradesh ────────────────────────────────────────────────────────
    'rewa': 15000,
    'satna': 16000,
    'sagar': 16000,
    'ujjain': 20000,
    'dewas': 18000,
    'ratlam': 18000,
    'mandsaur': 16000,
    'neemuch': 16000,
    'khandwa': 15000,
    'burhanpur': 15000,
    'khargone': 14000,
    'dhar': 14000,
    'jhabua': 12000,
    'alirajpur': 11000,
    'barwani': 12000,
    'betul': 14000,
    'hoshangabad': 16000, 'narmadapuram': 16000,
    'raisen': 14000,
    'vidisha': 15000,
    'sehore': 14000,
    'rajgarh': 13000,
    'shajapur': 14000,
    'shivpuri': 13000,
    'guna': 13000,
    'ashoknagar': 13000,
    'datia': 13000,
    'bhind': 13000,
    'morena': 14000,
    'sheopur': 12000,
    'panna': 12000,
    'katni': 16000,
    'narsinghpur': 14000,
    'chhindwara': 15000,
    'seoni': 13000,
    'mandla': 12000,
    'dindori': 11000,
    'umaria': 12000,
    'shahdol': 14000,
    'anuppur': 13000,
    'sidhi': 12000,
    'singrauli': 18000,  // industrial/power
    'balaghat': 14000,
    'tikamgarh': 12000, 'niwari': 12000,
    'chhatarpur': 13000,
    'damoh': 14000,
    'harda': 13000,
    'agar malwa': 13000,
    'maihar': 14000,
    // ── Punjab ────────────────────────────────────────────────────────────────
    'hoshiarpur': 22000,
    'gurdaspur': 20000,
    'pathankot': 22000,
    'moga': 22000,
    'firozpur': 18000,
    'fazilka': 16000,
    'muktsar': 18000,
    'faridkot': 18000,
    'mansa': 16000,
    'sangrur': 20000,
    'barnala': 18000,
    'malerkotla': 18000,
    'fatehgarh sahib': 22000,
    'rupnagar': 22000, 'ropar': 22000,
    'nawanshahr': 20000,
    'kapurthala': 20000,
    'tarn taran': 18000,
    // ── Haryana ───────────────────────────────────────────────────────────────
    'jhajjar': 26000,
    'fatehabad': 18000,
    'palwal': 22000,
    'nuh': 15000, 'mewat': 15000,
    'charkhi dadri': 18000,
    'mahendragarh': 18000,
    // ── Uttarakhand ───────────────────────────────────────────────────────────
    'almora': 18000,
    'pauri': 16000,
    'tehri': 16000,
    'uttarkashi': 16000,
    'chamoli': 16000,
    'rudraprayag': 16000,
    'bageshwar': 15000,
    'champawat': 15000,
    'pithoragarh': 18000,
    'udham singh nagar': 24000,
    // ── Himachal Pradesh ──────────────────────────────────────────────────────
    'chamba': 16000,
    'lahaul and spiti': 16000, 'lahaul': 16000,
    'sirmaur': 16000,
    'kinnaur': 18000,
    // ── Assam ─────────────────────────────────────────────────────────────────
    'silchar': 18000,
    'dibrugarh': 20000,
    'jorhat': 18000,
    'nagaon': 16000,
    'tinsukia': 18000,
    'sivasagar': 16000,
    'golaghat': 15000,
    'dhemaji': 13000,
    'bongaigaon': 15000,
    'kokrajhar': 13000,
    'barpeta': 13000,
    'nalbari': 15000,
    'tezpur': 16000, 'sonitpur': 16000,
    'darrang': 13000,
    'morigaon': 13000,
    'hojai': 15000,
    'dima hasao': 14000, 'haflong': 14000,
    'cachar': 15000,
    'hailakandi': 13000,
    'karimganj': 13000,
    'majuli': 14000,
    'biswanath': 13000,
    // ── J&K / Ladakh ──────────────────────────────────────────────────────────
    'leh': 22000,
    'kargil': 18000,
    'anantnag': 18000,
    'baramulla': 18000,
    'kupwara': 16000,
    'sopore': 18000,
    'kathua': 18000,
    'udhampur': 18000,
    'rajouri': 16000,
    'poonch': 15000,
    'doda': 15000,
    'kishtwar': 15000,
    'ramban': 15000,
    'reasi': 14000,
    'samba': 18000,
    'bandipora': 16000,
    'budgam': 20000,
    'ganderbal': 18000,
    'kulgam': 15000,
    'pulwama': 18000,
    'shopian': 15000,
    // ── Goa ───────────────────────────────────────────────────────────────────
    'ponda': 28000,
    'calangute': 32000,
    'candolim': 32000,
    // ── Puducherry ────────────────────────────────────────────────────────────
    'puducherry': 26000, 'pondicherry': 26000,
    'karaikal': 18000,
    'mahe': 24000,
    'yanam': 16000,
    // ── North-East ────────────────────────────────────────────────────────────
    'dimapur': 20000,
    'tawang': 20000,
    'pasighat': 16000,
    'deomali': 13000,
    'mokokchung': 16000, 'wokha': 14000,
    'tuensang': 13000, 'phek': 13000,
    'peren': 13000, 'longleng': 13000,
    'kiphire': 12000, 'mon': 12000, 'zunheboto': 13000,
    'senapati': 13000, 'churachandpur': 13000,
    'bishnupur': 15000, 'thoubal': 15000,
    'ukhrul': 13000, 'chandel': 12000,
    'tamenglong': 12000, 'jiribam': 13000,
    'lunglei': 15000, 'champhai': 15000, 'serchhip': 15000,
    'kolasib': 14000, 'lawngtlai': 13000, 'mamit': 13000,
    'east khasi hills': 20000, 'west khasi hills': 15000,
    'ri bhoi': 16000, 'east jaintia hills': 14000,
    'west garo hills': 14000, 'east garo hills': 13000,
    'south garo hills': 13000,
    'east sikkim': 24000, 'west sikkim': 18000,
    'north sikkim': 18000, 'south sikkim': 22000,
    'west tripura': 18000, 'south tripura': 15000,
    'north tripura': 15000, 'dhalai': 14000,
    'gomati': 15000, 'sepahijala': 16000, 'unakoti': 15000,
    'khowai': 15000,
    // ── Andaman & Nicobar ─────────────────────────────────────────────────────
    'port blair': 28000,
    'north and middle andaman': 22000,
    'south andaman': 26000,
    'nicobar': 20000,
  };

  // ── District → baseline income (₹/month) ────────────────────────────────
  // Used when GPS resolves to a district name not matched as a city.
  static const Map<String, int> _districtIncome = {
    // UP
    'sonbhadra': 18000, 'mirzapur': 14000, 'chandauli': 13000,
    'singrauli': 18000, 'shravasti': 11000, 'balrampur': 11000,
    'siddharthnagar': 12000, 'maharajganj': 12000, 'kushinagar': 13000,
    'sant kabir nagar': 12000, 'basti': 13000, 'gonda': 13000,
    'bahraich': 12000, 'etah': 13000, 'kasganj': 13000,
    'auraiya': 13000, 'hamirpur': 12000, 'mahoba': 12000,
    'banda': 12000, 'chitrakoot': 11000, 'lalitpur': 12000,
    'jalaun': 12000,
    // Bihar
    'rohtas': 12000, 'kaimur': 11000, 'buxar': 12000,
    'aurangabad': 11000, 'arwal': 11000, 'jehanabad': 11000,
    'vaishali': 12000, 'saran': 12000,
    'west champaran': 11000, 'east champaran': 12000, 'gopalganj': 12000,
    // Jharkhand
    'west singhbhum': 15000, 'east singhbhum': 20000,
    'palamu': 12000, 'chatra': 13000, 'koderma': 14000,
    'lohardaga': 13000, 'gumla': 12000, 'simdega': 12000,
    'khunti': 12000, 'pakur': 12000, 'godda': 12000,
    'sahibganj': 12000, 'dumka': 13000, 'jamtara': 12000,
    'latehar': 12000,
    // CG
    'bastar': 13000, 'dantewada': 11000, 'sukma': 10000,
    'bijapur': 11000, 'narayanpur': 11000, 'kabirdham': 12000,
    'balod': 13000, 'baloda bazar': 13000, 'gariaband': 12000,
    'bemetara': 13000, 'mungeli': 13000,
    'janjgir champa': 16000, 'koriya': 14000, 'jashpur': 12000,
    'surajpur': 13000,
    // Odisha
    'nuapada': 11000, 'kalahandi': 11000, 'kandhamal': 11000,
    'boudh': 11000, 'subarnapur': 11000, 'gajapati': 11000,
    'malkangiri': 11000, 'nabarangpur': 11000,
    'bolangir': 13000, 'rayagada': 13000, 'koraput': 13000,
    'kendujhar': 14000,
    // WB
    'jhargram': 13000, 'purulia': 14000, 'bankura': 15000,
    'birbhum': 15000, 'murshidabad': 15000, 'malda': 16000,
    // MP
    'sheopur': 12000, 'panna': 12000, 'damoh': 14000,
    'mandla': 12000, 'dindori': 11000, 'umaria': 12000,
    'anuppur': 13000, 'sidhi': 12000, 'alirajpur': 11000,
    'jhabua': 12000, 'barwani': 12000, 'tikamgarh': 12000,
    'niwari': 12000, 'chhatarpur': 13000, 'harda': 13000,
    // Rajasthan
    'barmer': 14000, 'jaisalmer': 13000, 'dungarpur': 13000,
    'banswara': 13000, 'baran': 13000, 'jhalawar': 13000,
    'bundi': 14000, 'karauli': 13000, 'dholpur': 14000,
    'sawai madhopur': 14000, 'dausa': 14000, 'tonk': 15000,
    'nagaur': 14000, 'sirohi': 14000,
    // Maharashtra
    'gadchiroli': 11000, 'nandurbar': 13000, 'washim': 13000,
    'hingoli': 13000, 'osmanabad': 14000,
    // Karnataka
    'yadgir': 13000, 'chamarajanagar': 14000, 'raichur': 15000,
    'koppal': 14000, 'bidar': 15000,
    // TN
    'ramanathapuram': 14000, 'sivaganga': 15000,
    'ariyalur': 14000, 'perambalur': 14000, 'kallakurichi': 14000,
    'tenkasi': 14000,
    // AP
    'srikakulam': 14000, 'vizianagaram': 15000,
    'parvathipuram manyam': 13000, 'alluri sitharama raju': 13000,
    // Telangana
    'mulugu': 12000, 'jayashankar bhupalpally': 13000,
    'kumuram bheem asifabad': 12000,
    // Gujarat
    'dang': 11000, 'dahod': 13000, 'chhota udaipur': 13000,
    'tapi': 14000,
    // Assam
    'dima hasao': 14000, 'karbi anglong': 13000,
    'west karbi anglong': 13000, 'dhemaji': 13000,
    'morigaon': 13000, 'south salmara mankachar': 12000,
    'bajali': 13000, 'tamulpur': 13000, 'biswanath': 13000,
    // HP
    'lahaul and spiti': 16000, 'kinnaur': 18000, 'sirmaur': 16000,
    'chamba': 16000,
    // Uttarakhand
    'chamoli': 16000, 'uttarkashi': 16000, 'rudraprayag': 16000,
    'tehri garhwal': 16000, 'pauri garhwal': 16000,
    'bageshwar': 15000, 'champawat': 15000,
    // Manipur
    'churachandpur': 13000, 'senapati': 13000, 'ukhrul': 13000,
    'chandel': 12000, 'tamenglong': 12000, 'bishnupur': 15000,
    'thoubal': 15000, 'jiribam': 13000,
    // Meghalaya
    'east khasi hills': 20000, 'west khasi hills': 15000,
    'south west khasi hills': 15000, 'ri bhoi': 16000,
    'east jaintia hills': 14000, 'west jaintia hills': 14000,
    'east garo hills': 13000, 'west garo hills': 14000,
    'south garo hills': 13000, 'north garo hills': 13000,
    // Mizoram
    'lunglei': 15000, 'champhai': 15000, 'serchhip': 15000,
    'kolasib': 14000, 'lawngtlai': 13000, 'mamit': 13000,
    'saitual': 13000, 'hnahthial': 13000, 'khawzawl': 13000,
    // Nagaland
    'mokokchung': 16000, 'tuensang': 13000, 'wokha': 14000,
    'phek': 13000, 'peren': 13000, 'longleng': 13000,
    'kiphire': 12000, 'mon': 12000, 'zunheboto': 13000,
    'noklak': 12000, 'tseminyu': 13000,
    // Arunachal
    'tawang': 20000, 'west kameng': 16000, 'east kameng': 15000,
    'papum pare': 20000, 'upper subansiri': 14000,
    'west siang': 16000, 'east siang': 16000, 'upper siang': 14000,
    'changlang': 15000, 'tirap': 14000, 'longding': 13000,
    'lohit': 15000, 'anjaw': 13000,
    // Sikkim
    'east sikkim': 24000, 'west sikkim': 18000,
    'north sikkim': 18000, 'south sikkim': 22000,
    // Tripura
    'west tripura': 18000, 'south tripura': 15000,
    'north tripura': 15000, 'dhalai': 14000, 'khowai': 15000,
    'gomati': 15000, 'sipahijala': 16000, 'unakoti': 15000,
    // Goa
    'north goa': 32000, 'south goa': 26000,
    // J&K
    'anantnag': 18000, 'baramulla': 18000, 'bandipora': 16000,
    'budgam': 20000, 'ganderbal': 18000, 'kulgam': 15000,
    'pulwama': 18000, 'shopian': 15000, 'kupwara': 16000,
    'kathua': 18000, 'udhampur': 18000, 'rajouri': 16000,
    'poonch': 15000, 'doda': 15000, 'kishtwar': 15000,
    'ramban': 15000, 'reasi': 14000, 'samba': 18000,
    // Ladakh
    'leh': 22000, 'kargil': 18000,
    // A&N
    'north and middle andaman': 22000, 'south andaman': 26000,
    'nicobar': 20000,
  };

  // ── State / UT baseline income (₹/month) — final fallback ───────────────
  static const Map<String, int> _stateIncome = {
    'maharashtra': 32000,
    'karnataka': 30000,
    'tamil nadu': 26000,
    'telangana': 30000,
    'andhra pradesh': 22000,
    'kerala': 26000,
    'gujarat': 26000,
    'rajasthan': 18000,
    'madhya pradesh': 16000,
    'chhattisgarh': 16000,
    'uttar pradesh': 14000,
    'bihar': 12000,
    'jharkhand': 16000,
    'odisha': 16000,
    'west bengal': 20000,
    'punjab': 24000,
    'haryana': 28000,
    'himachal pradesh': 22000,
    'uttarakhand': 22000,
    'delhi': 50000,
    'national capital territory of delhi': 50000,
    'goa': 32000,
    'assam': 16000,
    'manipur': 15000,
    'meghalaya': 18000,
    'tripura': 16000,
    'nagaland': 16000,
    'mizoram': 18000,
    'arunachal pradesh': 16000,
    'sikkim': 22000,
    'jammu and kashmir': 18000,
    'jammu & kashmir': 18000,
    'ladakh': 20000,
    'chandigarh': 42000,
    'puducherry': 24000, 'pondicherry': 24000,
    'andaman and nicobar islands': 24000,
    'andaman & nicobar': 24000,
    'lakshadweep': 20000,
    'dadra and nagar haveli and daman and diu': 22000,
    'dadra and nagar haveli': 20000,
    'daman and diu': 22000,
    'daman': 22000, 'diu': 22000,
  };

  static String _zoneName(int income) {
    if (income >= 60000) return 'High-Income Metro';
    if (income >= 40000) return 'Premium Metro';
    if (income >= 28000) return 'Tier-1 City';
    if (income >= 20000) return 'Tier-2 City';
    if (income >= 15000) return 'Tier-3 City';
    if (income >= 12000) return 'Small Town';
    return 'Rural / Low-Income Area';
  }

  static String _zoneDescription(int income) {
    if (income >= 60000) return 'High-income metro — targets reflect higher earning potential';
    if (income >= 40000) return 'Premium city — targets reflect above-average incomes';
    if (income >= 28000) return 'Tier-1 city — targets based on local average income';
    if (income >= 20000) return 'Tier-2 city — targets adjusted for local income levels';
    if (income >= 15000) return 'Tier-3 city — targets reflect modest local incomes';
    if (income >= 12000) return 'Small town — targets calibrated to local earnings';
    return 'Rural area — targets reflect local income baseline';
  }

  // ── Public API ────────────────────────────────────────────────────────────

  static Future<GeoResult?> getCached() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_keyTimestamp) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - ts >
        _cacheTtlHours * 3600 * 1000) { return null; }

    final income = prefs.getInt(_keyIncome) ?? _nationalMedian;
    final city = prefs.getString(_keyCity) ?? '';
    final subLocality = prefs.getString(_keySubLocality) ?? '';
    final district = prefs.getString(_keyDistrict) ?? '';
    final state = prefs.getString(_keyState) ?? '';
    return GeoResult(
      city: city.isNotEmpty ? city : district,
      subLocality: subLocality,
      state: state,
      baselineMonthlyIncome: income,
      zoneName: _zoneName(income),
      zoneDescription: _zoneDescription(income),
    );
  }

  static Future<GeoResult> fetchAndCache() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) { return _baseline(); }
      if (!await Geolocator.isLocationServiceEnabled()) { return _baseline(); }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (kIsWeb) return _baseline();

      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isEmpty) return _baseline();

      final p = placemarks.first;
      final city       = (p.locality ?? '').trim();
      final subLocality = (p.subLocality ?? '').trim();
      final district   = (p.subAdministrativeArea ?? '').trim();
      final state      = (p.administrativeArea ?? '').trim();

      final income = _lookupIncome(city, subLocality, district, state);
      final result = GeoResult(
        city: city.isNotEmpty ? city : district,
        subLocality: subLocality,
        state: state,
        baselineMonthlyIncome: income,
        zoneName: _zoneName(income),
        zoneDescription: _zoneDescription(income),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCity, city);
      await prefs.setString(_keySubLocality, subLocality);
      await prefs.setString(_keyDistrict, district);
      await prefs.setString(_keyState, state);
      await prefs.setInt(_keyIncome, income);
      await prefs.setInt(_keyTimestamp, DateTime.now().millisecondsSinceEpoch);

      return result;
    } catch (e) {
      log('GeoService error: $e');
      return _baseline();
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static int _lookupIncome(
      String city, String subLocality, String district, String state) {
    // 1. Ultra-premium sub-locality keywords
    final combined = '${subLocality.toLowerCase()} ${city.toLowerCase()}';
    for (final kw in _zoneAKeywords) {
      if (combined.contains(kw)) return _zoneAIncome;
    }

    // 2. Exact city match
    final cityKey = city.toLowerCase().trim();
    if (cityKey.isNotEmpty && _cityIncome.containsKey(cityKey)) {
      return _cityIncome[cityKey]!;
    }

    // 3. Partial city match
    if (cityKey.isNotEmpty) {
      for (final entry in _cityIncome.entries) {
        if (cityKey.contains(entry.key) || entry.key.contains(cityKey)) {
          return entry.value;
        }
      }
    }

    // 4. Exact district match
    final districtKey = district.toLowerCase().trim();
    if (districtKey.isNotEmpty && _districtIncome.containsKey(districtKey)) {
      return _districtIncome[districtKey]!;
    }

    // 5. Partial district match (also checks city table — district HQ = city name)
    if (districtKey.isNotEmpty) {
      for (final entry in _districtIncome.entries) {
        if (districtKey.contains(entry.key) || entry.key.contains(districtKey)) {
          return entry.value;
        }
      }
      if (_cityIncome.containsKey(districtKey)) {
        return _cityIncome[districtKey]!;
      }
    }

    // 6. State fallback
    final stateKey = state.toLowerCase().trim();
    if (stateKey.isNotEmpty && _stateIncome.containsKey(stateKey)) {
      return _stateIncome[stateKey]!;
    }
    if (stateKey.isNotEmpty) {
      for (final entry in _stateIncome.entries) {
        if (stateKey.contains(entry.key) || entry.key.contains(stateKey)) {
          return entry.value;
        }
      }
    }

    // 7. National median
    return _nationalMedian;
  }

  static GeoResult _baseline() => const GeoResult(
        city: '',
        subLocality: '',
        state: '',
        baselineMonthlyIncome: _nationalMedian,
        zoneName: 'Standard',
        zoneDescription: 'Location not detected — national median income used',
      );
}

class GeoResult {
  final String city;
  final String subLocality;
  final String state;
  /// Estimated average monthly income (₹) for this location's salaried user.
  /// Used as the expense baseline when no real transaction history exists.
  final int baselineMonthlyIncome;
  final String zoneName;
  final String zoneDescription;

  const GeoResult({
    required this.city,
    required this.subLocality,
    required this.state,
    required this.baselineMonthlyIncome,
    required this.zoneName,
    required this.zoneDescription,
  });

  String get displayLocation {
    if (subLocality.isNotEmpty && city.isNotEmpty) return '$subLocality, $city';
    if (city.isNotEmpty) return city;
    return 'Unknown location';
  }
}
