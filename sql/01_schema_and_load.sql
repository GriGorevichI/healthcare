CREATE TABLE healthcare(
    patient_id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    age INT,
    gender VARCHAR(10),
    blood_type VARCHAR(5),
    medical_condition VARCHAR(50),
    date_of_admission DATE NOT NULL,
    doctor VARCHAR(50),
    hospital TEXT,
    insurance_provider TEXT,
    billing_amount DECIMAL(10,2),
    room_number INT,
    admission_type VARCHAR(10),
    discharge_date DATE,
    medication TEXT,
    test_results VARCHAR(20),
    length_of_stay INT
);
COPY healthcare (
    name,
    age,
    gender,
    blood_type,
    medical_condition,
    date_of_admission,
    doctor,
    hospital,
    insurance_provider,
    billing_amount,
    room_number,
    admission_type,
    discharge_date,
    medication,
    test_results,
    length_of_stay)
FROM '/Users/grigorijgorevic/Desktop/SQL_PROJECTS/healthcare/Healthcare_cleaned.csv' 
DELIMITER ','
CSV HEADER;