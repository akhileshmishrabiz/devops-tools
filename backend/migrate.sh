#!/bin/bash

# Exit on error
set -e

# Export Flask app
export FLASK_APP=run.py
export HOST=devops-learning-db.devops-learning.svc.cluster.local

echo "Running database migrations..."

# Check if migrations directory exists
if [ ! -d "migrations" ]; then
    echo "Initializing migrations directory..."
    flask db init
fi

# Try to upgrade first (in case there are existing migrations)
echo "Attempting to upgrade existing migrations..."
flask db upgrade || true

# Create and apply new migration if needed
echo "Creating new migration if needed..."
flask db migrate -m "Auto-generated migration" || true

echo "Applying migrations..."
flask db upgrade

echo "Checking if seed data is needed..."
# Only run seed data if topics table is empty
PGPASSWORD=postgrespassword psql -h $HOST -U postgres -d devops_learning -t -c "SELECT COUNT(*) FROM topics" | grep -q "0" && {
    echo "Running seed data..."
    python seed_data.py
} || {
    echo "Database already contains data, skipping seed"
}

echo "Database setup completed successfully!"