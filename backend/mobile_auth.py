"""Email ownership challenges for the mobile API."""
import hashlib
import hmac
import re
import secrets
import smtplib
import ssl
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
from server import Problem, require, text, integer

class MobileAuth:
    def __init__(self, config):
        self.config = config

    def public_config(self):
        c = self.config()
        return dict(email_enabled=all(c.get(k) for k in ('SMTP_USERNAME','SMTP_PASSWORD','SMTP_FROM')) and len(c.get('EMAIL_OTP_SECRET','')) >= 32)

    def send_mail(self, email, code):
        c = self.config()
        require(all(c.get(k) for k in ('SMTP_USERNAME','SMTP_PASSWORD','SMTP_FROM')), 'Email sending is not ready. Please contact Lumear support.', 503)
        message = EmailMessage()
        message['From'], message['To'] = c['SMTP_FROM'], email
        message['Subject'] = 'Your Lumear verification code'
        message.set_content('Your Lumear verification code is '+code+'.\n\nIt expires in 10 minutes. If you did not request this, ignore this email.')
        try:
            with smtplib.SMTP(c.get('SMTP_HOST','smtp.gmail.com'), int(c.get('SMTP_PORT','587')), timeout=10) as smtp:
                smtp.ehlo(); smtp.starttls(context=ssl.create_default_context()); smtp.ehlo()
                smtp.login(c['SMTP_USERNAME'], c['SMTP_PASSWORD'].replace(' ',''))
                smtp.send_message(message)
        except (smtplib.SMTPException, OSError, ValueError):
            raise Problem('The verification email could not be sent. Please try again or contact Lumear support.', 503)

    def code_hash(self, email, salt, code):
        secret = self.config().get('EMAIL_OTP_SECRET','')
        require(len(secret)>=32, 'Email verification is not ready. Please contact Lumear support.', 503)
        return hmac.new(secret.encode(), (email+'|'+salt+'|'+code).encode(), hashlib.sha256).hexdigest()

    def send(self, db, email, purpose, user_id=None):
        email = text(email,'Email',3,254).lower()
        require(re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+',email), 'Enter a valid email address.')
        require(purpose in ('registration','account'), 'Invalid verification request.')
        # Named locks last until this request's DB connection closes, after commit.
        lock_name = 'lumear-otp:'+hashlib.sha256((self.config().get('MYSQL_DATABASE','')+'|'+email+'|'+purpose).encode()).hexdigest()[:40]
        db.execute('SELECT GET_LOCK(%s,3) acquired',(lock_name,))
        require(db.fetchone()['acquired']==1, 'Another code request is in progress. Please try again.',429)
        db.execute('SELECT created_at FROM email_otp_codes WHERE email=%s AND purpose=%s ORDER BY id DESC LIMIT 1',(email,purpose))
        old=db.fetchone();now=datetime.now(timezone.utc).replace(tzinfo=None)
        require(not old or (now-old['created_at']).total_seconds()>=60, 'Wait 60 seconds before sending another code.',429)
        code=f'{secrets.randbelow(1000000):06d}';salt=secrets.token_hex(16)
        digest='otp:'+salt+':'+self.code_hash(email,salt,code)
        db.execute('UPDATE email_otp_codes SET used_at=UTC_TIMESTAMP() WHERE email=%s AND purpose=%s AND used_at IS NULL',(email,purpose))
        db.execute('INSERT INTO email_otp_codes(user_id,email,code_hash,purpose,expires_at) VALUES(%s,%s,%s,%s,%s)',(user_id,email,digest,purpose,now+timedelta(minutes=10)))
        challenge=str(db.lastrowid)
        self.send_mail(email,code)
        return dict(challenge_id=challenge,message='A verification code was sent to your email.',expires_in=600)

    def verify(self, db, body):
        raw_id=str(body.get('challenge_id',''))
        require(raw_id.isascii() and raw_id.isdigit() and len(raw_id)<=19,'Invalid verification request.')
        challenge=integer(int(raw_id),'Verification request',1,2**63-1)
        code=text(body.get('code'),'Verification code',6,6)
        require(code.isascii() and code.isdigit(),'Enter the six-digit code from your email.')
        db.execute('SELECT * FROM email_otp_codes WHERE id=%s FOR UPDATE',(challenge,));row=db.fetchone()
        if not row or row['used_at'] or row['expires_at']<=datetime.now(timezone.utc).replace(tzinfo=None) or not row['code_hash'].startswith('otp:'):
            return dict(verified=False,message='This code expired or was used. Send a new code.')
        if row['attempts']>=5:return dict(verified=False,message='Too many incorrect attempts. Send a new code.')
        _,salt,digest=row['code_hash'].split(':')
        if not hmac.compare_digest(digest,self.code_hash(row['email'],salt,code)):
            db.execute('UPDATE email_otp_codes SET attempts=attempts+1 WHERE id=%s',(challenge,))
            return dict(verified=False,message='Incorrect code. Check your email and try again.')
        if row['purpose']=='account':
            db.execute('UPDATE users SET email_verified_at=UTC_TIMESTAMP(),updated_at=UTC_TIMESTAMP() WHERE id=%s AND email=%s',(row['user_id'],row['email']))
            db.execute('UPDATE email_otp_codes SET used_at=UTC_TIMESTAMP() WHERE id=%s',(challenge,))
            return dict(verified=True,message='Your email is verified. You can sign in.')
        proof=secrets.token_urlsafe(32)
        db.execute('UPDATE email_otp_codes SET code_hash=%s,expires_at=%s WHERE id=%s',('proof:'+hashlib.sha256(proof.encode()).hexdigest(),datetime.now(timezone.utc).replace(tzinfo=None)+timedelta(minutes=15),challenge))
        return dict(verified=True,verification_token=proof,message='Your email is verified.')

    def consume(self, db, email, proof):
        require(isinstance(proof,str) and 20<=len(proof)<=100,'Verify your email before creating your account.')
        db.execute("SELECT id FROM email_otp_codes WHERE email=%s AND purpose='registration' AND code_hash=%s AND used_at IS NULL AND expires_at>UTC_TIMESTAMP() FOR UPDATE",(email,'proof:'+hashlib.sha256(proof.encode()).hexdigest()))
        row=db.fetchone();require(row,'Your verification expired. Verify your email again.')
        db.execute('UPDATE email_otp_codes SET used_at=UTC_TIMESTAMP() WHERE id=%s',(row['id'],))

