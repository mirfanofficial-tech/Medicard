/// A plain-words line on what a common medicine is for, shown next to the patient's
/// medicines. General information only — never a dosing or prescribing suggestion.
String? medicinePurpose(String name) {
  final n = name.toLowerCase();
  const table = <String, String>{
    'metformin': 'Lowers blood sugar (diabetes)',
    'gliclazide': 'Lowers blood sugar (diabetes)',
    'insulin': 'Controls blood sugar (diabetes)',
    'ramipril': 'Lowers blood pressure and protects the kidneys',
    'lisinopril': 'Lowers blood pressure and protects the kidneys',
    'enalapril': 'Lowers blood pressure and protects the kidneys',
    'losartan': 'Lowers blood pressure',
    'amlodipine': 'Lowers blood pressure',
    'atorvastatin': 'Lowers cholesterol',
    'rosuvastatin': 'Lowers cholesterol',
    'simvastatin': 'Lowers cholesterol',
    'ibuprofen': 'Pain relief — ask your doctor before using',
    'diclofenac': 'Pain relief — ask your doctor before using',
    'naproxen': 'Pain relief — ask your doctor before using',
    'paracetamol': 'Pain and fever',
    'panadol': 'Pain and fever',
    'omeprazole': 'Reduces stomach acid',
    'pantoprazole': 'Reduces stomach acid',
    'salbutamol': 'Opens the airways (asthma)',
    'aspirin': 'Thins the blood',
    'clopidogrel': 'Thins the blood',
    'levothyroxine': 'Replaces thyroid hormone',
    'cetirizine': 'Allergy relief',
  };
  for (final e in table.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return null;
}
