import unittest
import requests
import json
from server import app

class BadbeatsToolsTests(unittest.TestCase):
    def setUp(self):
        self.app = app.test_client()
        self.base_url = 'http://localhost:8000'

    def test_home_page(self):
        """Test if home page loads successfully"""
        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)

    def test_api_tracks(self):
        """Test if tracks API endpoint returns correct data"""
        response = self.app.get('/api/tracks')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertIsInstance(data, list)

    def test_auth_endpoints(self):
        """Test authentication endpoints"""
        # Test registration
        register_data = {
            'username': 'testuser',
            'email': 'test@example.com',
            'password': 'testpass123'
        }
        response = self.app.post('/api/auth/register', 
                               json=register_data)
        self.assertEqual(response.status_code, 200)

        # Test login
        login_data = {
            'email': 'test@example.com',
            'password': 'testpass123'
        }
        response = self.app.post('/api/auth/login', 
                               json=login_data)
        self.assertEqual(response.status_code, 200)
        self.assertIn('token', json.loads(response.data))

    def test_subscription_endpoint(self):
        """Test subscription endpoint"""
        subscription_data = {
            'plan': 'premium'
        }
        response = self.app.post('/api/subscription', 
                               json=subscription_data)
        self.assertEqual(response.status_code, 200)

    def test_upload_endpoint(self):
        """Test file upload endpoint"""
        with open('test_audio.mp3', 'rb') as f:
            response = self.app.post('/api/upload', 
                                   data={'audio': f})
            self.assertEqual(response.status_code, 200)

def run_tests():
    """Run all tests"""
    unittest.main()

if __name__ == '__main__':
    run_tests()
