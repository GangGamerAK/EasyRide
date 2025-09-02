# Admin Dashboard for EasyRide

## Overview
The admin dashboard allows administrators to view all registered drivers and their verification documents including CNIC and driver license images.

## Features

### Admin Dashboard (`lib/views/admin_dashboard.dart`)
- **Driver List**: Displays all registered drivers with their basic information
- **Document Verification**: Shows CNIC and driver license images for each driver
- **Detailed View**: Tap on any driver to see full details and document images
- **Real-time Updates**: Pull to refresh to get the latest driver data

### Admin User Creation
- **Secure Access**: Admin role is only available for specific email addresses
- **Testing Interface**: Use the admin creation view for testing purposes

## How to Use

### 1. Creating an Admin User
There are two ways to create an admin user:

#### Method 1: Through Profile Creation (Recommended)
1. Sign up with an email containing "admin" or use "admin@easyride.com"
2. During profile creation, you'll see an "Admin" option
3. Select "Admin" role and complete the profile

#### Method 2: Using Admin Creation View (Testing)
1. On the welcome screen, click "Create Admin User (Testing)"
2. Enter email and password
3. Click "Create Admin User"

### 2. Accessing the Admin Dashboard
1. Login with admin credentials
2. The app will automatically redirect to the admin dashboard
3. View all registered drivers and their documents

### 3. Viewing Driver Documents
1. In the admin dashboard, you'll see a list of all drivers
2. Each driver card shows:
   - Profile image
   - Name and contact information
   - CNIC number
   - License number (if available)
   - Icons indicating document availability
3. Tap on any driver card to see detailed information including:
   - Full profile image
   - CNIC image (if uploaded)
   - Driver license image (if uploaded)

## Technical Implementation

### Files Created/Modified
- `lib/views/admin_dashboard.dart` - Main admin dashboard view
- `lib/views/admin_creation_view.dart` - Admin user creation interface
- `lib/services/firebase_service.dart` - Added admin user creation method
- `lib/main.dart` - Added admin role routing
- `lib/views/profile_creation_view.dart` - Added admin role option
- `lib/views/welcome_view.dart` - Added admin creation link

### Database Structure
The admin dashboard reads from the existing `users` collection in Firestore:
```javascript
{
  "email": "driver@example.com",
  "name": "Driver Name",
  "role": "driver",
  "cnic": "1234567890123",
  "cnicImageUrl": "https://...",
  "licenseNumber": "DL123456",
  "licenseImageUrl": "https://...",
  "profileImageUrl": "https://..."
}
```

### Security Considerations
- Admin role is restricted to specific email patterns
- Admin creation is limited to testing interface
- All document images are stored securely via ImgBB
- No sensitive data is stored in plain text

## Testing

### Creating Test Data
1. Create regular driver accounts through the normal signup process
2. Upload CNIC and license images during profile creation
3. Create an admin account using one of the methods above
4. Login as admin to view all driver data

### Expected Behavior
- Admin dashboard should load all drivers with their documents
- Tap on driver cards to see detailed information
- Pull to refresh should update the driver list
- Error handling for missing images or network issues

## Future Enhancements
- Driver approval/rejection system
- Document verification status tracking
- Bulk operations on driver accounts
- Export driver data functionality
- Advanced filtering and search capabilities 