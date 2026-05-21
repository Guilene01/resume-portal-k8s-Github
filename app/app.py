import os
import json
import base64
import uuid
import socket
import time
from datetime import datetime
from flask import Flask, request, jsonify
import boto3
import psycopg2

def init_db():
    """Create tables if they don't exist on startup."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS applications (
                id SERIAL PRIMARY KEY,
                full_name VARCHAR(255) NOT NULL,
                email VARCHAR(255) NOT NULL,
                phone VARCHAR(50),
                position VARCHAR(255),
                skills TEXT,
                resume_s3_key VARCHAR(500),
                submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        ''')
        conn.commit()
        cursor.close()
        conn.close()
        app.logger.info('Database initialized successfully!')
    except Exception as e:
        app.logger.error(f'Database initialization failed: {e}')

# Run on startup
with app.app_context():
    init_db()


app = Flask(__name__)


# AWS region — explicit is better than implicit
REGION = os.environ.get('AWS_REGION', 'us-east-1')


# AWS clients automatically use the EC2 instance's IAM role
s3 = boto3.client('s3', region_name=REGION)
secrets = boto3.client('secretsmanager', region_name=REGION)
ses = boto3.client('ses', region_name=REGION)


# Configuration from environment variables
RESUME_BUCKET = os.environ.get('RESUME_BUCKET')
DB_SECRET_NAME = os.environ.get('DB_SECRET_NAME')
SENDER_EMAIL = os.environ.get('SENDER_EMAIL')
ALLOWED_ORIGIN = os.environ.get('ALLOWED_ORIGIN', '*')  # FIX #6: lock down CORS in prod


# FIX #1: Cache DB credentials with a TTL so rotated secrets are picked up
_db_creds = None
_db_creds_fetched_at = 0
DB_CREDS_TTL = 300  # 5 minutes




def get_db_credentials():
    """Fetch DB credentials from Secrets Manager, refreshing every 5 minutes."""
    global _db_creds, _db_creds_fetched_at
    if _db_creds is None or (time.time() - _db_creds_fetched_at) > DB_CREDS_TTL:
        response = secrets.get_secret_value(SecretId=DB_SECRET_NAME)
        _db_creds = json.loads(response['SecretString'])
        _db_creds_fetched_at = time.time()
    return _db_creds




def get_db_connection():
    """Get a fresh database connection."""
    creds = get_db_credentials()
    return psycopg2.connect(
        host=creds['host'],
        port=creds['port'],
        database='portal',
        user=creds['username'],
        password=creds['password'],
        connect_timeout=5
    )




# CRITICAL: Health check endpoint — the ALB calls this constantly
@app.route('/health')
def health():
    """Simple health check - just returns 200."""
    return jsonify({'status': 'healthy'}), 200


# Useful for testing load balancing
@app.route('/whoami')
def whoami():
    """Returns the hostname so we can see WHICH instance handled the request."""
    return jsonify({
        'hostname': socket.gethostname(),
        'timestamp': datetime.utcnow().isoformat()
    })




# Status page
@app.route('/')
def index():
    return jsonify({
        'service': 'resume-portal',
        'status': 'ok',
        'instance': socket.gethostname()
    })




# Main submission endpoint
@app.route('/submit', methods=['POST', 'OPTIONS'])
def submit_application():
    if request.method == 'OPTIONS':
        return _cors_response('', 200)


    try:
        data = request.json or {}


        # FIX #4: Validate all required fields up front
        required_fields = ['fullName', 'email', 'phone', 'position', 'skills', 'resume', 'fileName']
        missing = [f for f in required_fields if not data.get(f)]
        if missing:
            return _cors_response({'error': f'Missing required fields: {missing}'}, 400)


        full_name = data['fullName']
        email = data['email']
        phone = data['phone']
        position = data['position']
        skills = data['skills']           # expected to be a list
        resume_base64 = data['resume']
        original_filename = data['fileName']


        # FIX #4 (continued): Basic email format check
        if '@' not in email or '.' not in email.split('@')[-1]:
            return _cors_response({'error': 'Invalid email address'}, 400)


        # Decode and validate the resume bytes
        try:
            resume_bytes = base64.b64decode(resume_base64)
        except Exception:
            return _cors_response({'error': 'Invalid base64 for resume'}, 400)


        # FIX #7: Reject non-PDF uploads
        if not resume_bytes.startswith(b'%PDF'):
            return _cors_response({'error': 'Only PDF files are accepted'}, 400)


        # Generate unique S3 key
        now = datetime.utcnow()
        unique_id = str(uuid.uuid4())[:8]
        s3_key = f"resumes/{now.year}/{now.month:02d}/{unique_id}_{original_filename}"


        # FIX #5: Insert into DB FIRST so we can skip S3 upload on failure
        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO applications
                    (full_name, email, phone, position, skills, resume_s3_key)
                VALUES (%s, %s, %s, %s, %s::jsonb, %s)
                RETURNING id;
            """, (
                full_name,
                email,
                phone,
                position,
                json.dumps(skills),   # FIX #3: serialize skills list to JSON for jsonb column
                s3_key
            ))
            application_id = cursor.fetchone()[0]
            conn.commit()
            cursor.close()
        finally:
            conn.close()


        # Upload PDF to S3 only after DB insert succeeds
        s3.put_object(
            Bucket=RESUME_BUCKET,
            Key=s3_key,
            Body=resume_bytes,
            ContentType='application/pdf'
        )


        # Send confirmation email
        ses.send_email(
            Source=SENDER_EMAIL,
            Destination={'ToAddresses': [email]},
            Message={
                'Subject': {'Data': f'Application Received - {position}'},
                'Body': {'Text': {'Data': (
                    f"Hi {full_name}, thanks for applying!\n"
                    f"Application ID: {application_id}"
                )}}
            }
        )


        return _cors_response({
            'message': 'Application submitted',
            'applicationId': application_id,
            'instance': socket.gethostname()
        }, 200)


    except Exception as e:
        app.logger.error(f"Submission failed: {e}")
        # FIX #4: Don't leak internal error details to the client
        return _cors_response({'error': 'An internal error occurred. Please try again.'}, 500)




def _cors_response(body, status):
    """CORS-friendly response helper."""
    response = jsonify(body) if body != '' else jsonify({})
    # FIX #6: Use a configurable origin instead of wildcard *
    response.headers['Access-Control-Allow-Origin'] = ALLOWED_ORIGIN
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    response.headers['Access-Control-Allow-Methods'] = 'OPTIONS,POST'
    response.status_code = status
    return response




if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)



