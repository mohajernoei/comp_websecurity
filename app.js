//Apr 5 2025, edited by Reza
const mysql = require('mysql');
const express = require('express');
const session = require('express-session');
const path = require('path');

const connection = mysql.createConnection({
    host: 'localhost',
    user: 'twitter_admin',
password: 'MyAppPassw0rd!',

    database: 'twitter_miniapp'
});

const app = express();

app.set('view engine', 'ejs');

app.use(session({
    secret: 'your-secret-key',
    resave: false,
    saveUninitialized: true,
    cookie: { secure: false } // Set 'secure' to true if using HTTPS
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, "public")));

app.get('/data', function(request, response) {
    response.json(info);
});

app.get('/', function(request, response) {
    response.sendFile(path.join(__dirname, "/public/login.html"));
});

app.get('/register', function(request, response) {
    response.sendFile(path.join(__dirname, "/public/register.html"));
});

app.post('/register', function(request, response) {
    let email = request.body.email;
    let password = request.body.password;
    let fullname = request.body.fullname;

    let q = "INSERT INTO users (fullname, password, email) VALUES ('" + fullname +
        "', '" + password + "', '" + email + "')";
    console.log(q);

    if (email && password && fullname) {
        connection.query(q, function(error, results, fields) {
            if (error) throw error;
            response.send('Registered Successfully');
        });
    } else {
        response.send("Please enter Fullname, Password and Email!");
    }
});

app.post('/auth', function (request, response) {
    let email = request.body.email;
    let password = request.body.password;

    let q = "SELECT * FROM users WHERE email = '" + email + "' AND password = '" + password + "'";
    console.log("Logging in query: ", q);

    // Ensure both email and password are provided
    if (email && password) {
        // Execute the SQL query
        connection.query(q, function(error, results, fields) {
            if (error) throw error;
            if (results.length > 0) {
                // Set session variables
                request.session.loggedin = true;
                request.session.email = results[0].email;
                request.session.fullname = results[0].fullname;

                console.log("Session after login:", request.session); // Debugging log
                response.redirect('/home');
            } else {
                request.session.loggedin = false;
                response.send("Incorrect email or password");
            }
        });
    } else {
        request.session.loggedin = false;
        response.send("Please enter your email and password!");
    }
});

app.get('/home', function(request, response) {
    if (request.session.loggedin === true) {
        response.render('home', { email: request.session.email, fullname: request.session.fullname });
    } else {
        response.send('Please <a href="/">login</a> to view this page!');
    }
});

app.get('/user/update', function(request, response) {
    if (request.session.loggedin === true) {
        let new_email = request.query.email;
        let q = "UPDATE users SET email = '" + new_email + "' WHERE email = '" + request.session.email + "'";
        if (new_email) {
            connection.query(q, function(error, results, fields) {
                if (error) throw error;
                request.session.email = new_email;
                response.send(new_email);
            });
        }
    } else {
        response.send('Unauthorized action!');
    }
});

app.post('/account', function (request, response) {
    console.log("Received request to delete account.");
    console.log("Session data:", request.session); // Debugging log

    if (!request.session.loggedin || !request.session.email) {
        return response.status(401).send('Unauthorized action! Please log in.');
    }

    if (request.body['delete'] == 1) {
        let q = "DELETE FROM users WHERE email = ?";
        console.log(q);

        connection.query(q, [request.session.email], function (error, results) {
            if (error) throw error;

            // Destroy session after deletion
            request.session.destroy((err) => {
                if (err) return response.status(500).send('Error deleting account.');
                response.send('Account Deleted');
            });
        });
    } else {
        response.status(400).send('Invalid request!');
    }
});


app.get('/logout', function(request, response) {
    if (request.session.loggedin === true) {
        request.session.loggedin = false;
        response.redirect('/');
    } else {
        response.redirect('/');
    }
});

app.listen(3000);

