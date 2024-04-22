from flask import Flask, render_template, request
from pymongo import MongoClient
from os import environ

app = Flask(__name__)

# Connect to MongoDB
client = MongoClient(environ.get('MONGO_URL'))
db = client.candidate_database
collection = db.candidate_collection

# Ensure that there's an initial document
result = {
    "dogs": 0,
    "cats": 0
}

existing_document = collection.find_one(result)

if not existing_document:
    collection.insert_one(result)


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/result', methods=['POST'])
def process_result():
    vote = request.form.get('choice') 
    print(vote)
    if vote == "dog":
        collection.update_one({}, {"$inc": {"dogs": 1}})
    elif vote == "cat":
        collection.update_one({}, {"$inc": {"cats": 1}})

    # Retrieve the updated document from MongoDB
    survey_results = collection.find_one({}, {"_id": 0})
    print(survey_results)
    return render_template('result.html', survey_results=survey_results)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
