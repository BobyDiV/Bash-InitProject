#!/bin/bash
#  Файл выпонняет установку sequelize для postgres, express, ReactSSR

# Для того что бы все сработало:
# 1) npm init -y
# 2) добавляем в package.json
# "scripts": {
    # "start": "node app. js",
    # "dev": "nodemon app.js --ignore session --ext js, jsx, json"
# },
# 3) chmod +x BobyDiV_project_Init.sh
# 4) ./BobyDiV_project_Init.sh
# 5) настроить еслинт:(не обязательно)
# "rules": {
#   "no-console": 0,
#   "react/prop-types": 0,
#   "react/jsx-one-expression-per-line": 0,
#   "jsx-a11y/anchor-is-valid":0,
#   "jsx-a11y/label-has-associated-control": 0,
#   "jsx-a11y/tabindex-no-positive": 0,
#   "default-param - last": "NONE"
# }
# 6) настрой Prettier

npm i express
npm i @babel/core @babel/preset-env @babel/preset-react @babel/register react react-dom
npm i @babel/cli
npm i dotenv
npm i -D nodemon morgan
npm i --save sequelize pg pg-hstore
npm i --save-dev sequelize-cli
npm i express-session
npm i session-file-store
npm i @faker-js/faker
npm i bcrypt
npm i http-errors
npm i -D eslint

npx create-gitignore node


# создаем файл .sequelizerc
echo "require('dotenv').config()
const path = require('path');

 module.exports = {
 'config': path.resolve('db','config', 'dbconfig.json'),
 'models-path': path.resolve('db', 'models'),
 'seeders-path': path.resolve('db', 'seeders'),
 'migrations-path': path.resolve('db', 'migrations')
 };" > .sequelizerc

# инициализируем sequelize
npx sequelize-cli init

# перезаписываем файл dbconfig.json, чтобы использовать .env
echo '{
  "development": {
    "use_env_variable": "DB_URL",
    "dialect": "postgres"
  },
  "test": {
    "use_env_variable": "TEST_DB_URL",
    "host": "127.0.0.1",
    "dialect": "postgres"
  },
  "production": {
    "use_env_variable": "PROD_DB_URL",
    "host": "127.0.0.1",
    "dialect": "postgres"
  },
  "seederStorage": "sequelize",
  "seederStorageTableName": "SequelizeData"
}' > ./db/config/dbconfig.json

# создаем файл .env
echo 'DB_URL=postgres://postgres:postgres@localhost:5432/db_Name
PORT=3000
COOKIE_SEKRET=qwerty1234567890QWERTY
' > .env 

# создаем файл .env_example
echo 'DB_URL=postgres://[admin]:[password]@hostname:[PORT]/[dbName]
PORT=3000
COOKIE_SEKRET=[кодовое слово для шифрования COOKIE]
' > .env_example

# создаем файл app.js
echo "require('@babel/register');
require('dotenv').config();
const path = require('path');
const express = require('express');
const morgan = require('morgan');
const createError = require('http-errors');

// подключаем мидлварки
const checkConnect = require('./src/middlewares/checkConnect');
const ssr = require('./src/middlewares/ssr');

// подключаем сесию
const session = require('express-session');
const FileStore = require('session-file-store')(session);

const app = express();

const { PORT = 3001, COOKIE_SEKRET = 'secretik' } = process.env;
// Чтобы наши статические файлы были видны браузеру, мы должны их подключить
app.use(express.static(path.join(process.cwd(), 'public')));
app.use(express.urlencoded({ extended: true }));
app.use(ssr); // дополнительная middleware для вызова функции отрисовщика страниц
app.use(morgan('dev'));
app.use(express.json());

// * подключаем session, в sessionConfig = {...} данные для конфигурации сессии и cookie 
// * Конфиг для куки в виде файла сессий
const sessionConfig = {
  name: 'myProjectCookie', // * Название куки
  store: new FileStore(), // * подключение стора (БД для куки) для хранения
  secret: process.env.COOKIE_SEKRET ?? 'Секретное слово', // * ключ для шифрования куки прописан в.env
  resave: false, // * если true, пересохранит сессию, даже если она не менялась
  saveUninitialized: false, // * если false, куки появятся только при установке req.session
  cookie: {
    secure: false, // * http/https
    maxAge: 1000 * 60 * 60 * 24 * 2, // * время жизни в ms (2 дня)
    httpOnly: true, // * куки только по http
  },
};

// * Подключи сессии как мидлу
app.use(session(sessionConfig));

// Импортируем созданныe в отдельныx файлах рутеры.
const appRoutes = require('./src/routes/app.routes');
const userRoutes = require('./src/routes/user.routes');

app.use('/', appRoutes);
app.use('/users', checkConnect, userRoutes);

// Если HTTP-запрос дошёл до этой строчки, значит ни один из ранее встречаемых рутов не ответил
// на запрос.Это значит, что искомого раздела просто нет на сайте.Для таких ситуаций используется
// код ошибки 404. Создаём небольшое middleware, которое генерирует соответствующую ошибку.
app.use((req, res, next) => {
  const error = createError(
    404,
    'Запрашиваемой страницы не существует на сервере.'
  );
  next(error);
});

// Отлавливаем HTTP-запрос с ошибкой и отправляем на него ответ.
app.use((err, req, res) => {
  // Получаем текущий режим работы приложения.
  const appMode = req.app.get('env');
  // Создаём объект, в котором будет храниться ошибка.

  let error;

  // Если мы находимся в режиме разработки, то отправим в ответе настоящую ошибку.
  // В противном случае отправим пустой объект.
  if (appMode === 'development') {
    error = err;
  } else {
    error = {};
  }

  // Записываем информацию об ошибке и сам объект ошибки в специальные переменные,
  // доступные на сервере глобально, но только в рамках одного HTTP - запроса.
  res.locals.message = err.message;
  res.locals.error = error;

  // Задаём в будущем ответе статус ошибки. Берём его из объекта ошибки, если он там есть.
  // В противно случае записываем универсальный статуc ошибки на сервере - 500.
  res.status(err.status || 500);
  // Ренедрим React-компонент Error и отправляем его на клиент в качестве ответа.
  res.render(Error, res.locals);
});

app.listen(PORT, (err) => {
  app.locals.time = new Date();
  setInterval(() => {
    app.locals.time = new Date();
  }, 1000 * 60);
  if (err) return console.log('Ошибка запуска сервера.', err.message);
  console.log(\`🤖 Сервер запущен на http://localhost:\${PORT}\`);
});
" > app.js

mkdir -p public/assets
mkdir -p public/js
mkdir -p public/images
mkdir -p public/css
mkdir -p src
mkdir -p src/views
mkdir -p src/middlewares
mkdir -p src/lib
mkdir -p src/routes

# создадим набор views для отрисовки страниц
# Layout.jsx
echo "const React = require('react');
const Navbar = require('./Navbar');

function Layout(props) {
  const { title, time, children } = props;
  return (
    <html lang='en'>
      <head>
        <meta charSet='UTF-8' />
        <meta httpEquiv='X-UA-Compatible' content='IE=edge' />
        <meta name='viewport' content='width=device-width, initial-scale=1.0' />
        <link rel=\"icon\" type=\"image/x-icon\" href=\"/assets/favicon.ico\" />
        <link href=\"https://cdn.jsdelivr.net/npm/bootstrap@5.2.2/dist/css/bootstrap.min.css\" rel=\"stylesheet\" integrity=\"sha384-Zenh87qX5JnK2Jl0vWa8Ck2rdkQ2Bzep5IDxbcnCeuOxjzrPF/et3URy9Bv1WTRi\" crossOrigin=\"anonymous\" />
        <link rel=\"stylesheet\" href=\"/css/style.css\"/>
        <script src=\"https://cdn.jsdelivr.net/npm/bootstrap@5.2.2/dist/js/bootstrap.bundle.min.js\" integrity=\"sha384-OERcA2EqjJCMA+/3y+gxIOqMEjwtxJY7qPCqsdltbNJuaOe923+mo//f6V8Qbsw3\" crossOrigin=\"anonymous\" />
        <script defer src=\"/js/application.js\" />
        <title>myProject</title>
      </head>
      <body>
        <Navbar {...props} />
        <div className='container'>{children}</div>
      </body>
    </html>
  );
}

module.exports = Layout;
" > ./src/views/Layout.jsx

# Navbar.jsx
echo "const React = require('react');

function Navbar(props) {
  const { time, user } = props;
  return (
    <nav className='navbar navbar-expand-lg bg-primary'>
      <div className='container-fluid'>
        <a className='navbar-brand btn btn-primary' href='/'>
          Главная
        </a>
        <button
          className='navbar-toggler'
          type='button'
          data-bs-toggle='collapse'
          data-bs-target='#navbarSupportedContent'
          aria-controls='navbarSupportedContent'
          aria-expanded='false'
          aria-label='Toggle navigation'
        >
          <span className='navbar-toggler-icon' />
        </button>
        <div className='collapse navbar-collapse' id='navbarSupportedContent'>
          <ul className='navbar-nav me-auto mb-2 mb-lg-0'>
            <li className='nav-item'>
              <a
                className='nav-link btn btn-primary'
                aria-current='page'
                href='#'
              >
                Страница2
              </a>
            </li>
            <li className='nav-item'>
              <a
                className='nav-link btn btn-primary'
                aria-current='page'
                href='#'
              >
                Страница3
              </a>
            </li>
            <li className='nav-item'>
              <a className='nav-link'>{time.toLocaleString().slice(0, -3)}</a>
            </li>
          </ul>
          {user ? (
            <div className='userLogout'>
              <a href='/users/profile' className='btn btn-primary'>{\`Приветствую тебя, \${user.name}!\`}</a>
              <a className='btn btn-primary' href='/users/logout'>
                Выход
              </a>
            </div>
          ) : (
            <div className='logReg'>
              <a className='btn btn-primary' href='/users/login'>
                Вход
              </a>
              <a className='btn btn-primary' href='/users/newuser' >
                Регистрация
              </a>
            </div>
          )}
        </div>
      </div>
    </nav>
  );
}
module.exports = Navbar;
" > ./src/views/Navbar.jsx

# Home.jsx
echo "const React = require('react');
const Layout = require('./Layout');

function Home(props) {
  const { title } = props;
  return (
    <Layout {...props}>
      <div>
        <h2>{title}</h2>
      </div>
    </Layout>
  );
}

module.exports = Home;
" > ./src/views/Home.jsx

# Error.jsx
echo "const React = require('react');
const Layout = require('./Layout');

function Error(props) {
  const { message, error } = props;
  return (
    <Layout>
      <h1>{message}</h1>
      <h2>{error.status}</h2>
      <pre>{error.stack}</pre>
    </Layout>
  );
};
module.exports = Error;
" > ./src/views/Error.jsx

# Registration.jsx
echo 'const React = require("react");
const Layout = require("./Layout");

function Registration(props) {
  return (
    <Layout {...props}>
      <script defer src="/js/newuser.js" />
      <div>
        <form name="regForm">
          <h3>Добро пожаловать на страницу регистрации!</h3>
          <div className="mb-3">
            <label className="form-label" htmlFor="controlInput1">
              Укажите своё Имя...
            </label>
            <input
              type="text"
              className="form-control"
              id="controlInput1"
              placeholder="Моё имя..."
              aria-label="default input example"
              name="name"
              required
            />
          </div>
          <div className="mb-3">
            <label className="form-label" htmlFor="controlInput2">
              Укажите адрес электронной почты...
            </label>
            <input
              type="email"
              className="form-control"
              id="controlInput2"
              placeholder="name@example.com"
              aria-label="default input example"
              name="email"
              required
            />
          </div>
          <div className="mb-3">
            <label className="form-label" htmlFor="controlInput3">
              и обязательно введите пароль...
            </label>
            <input
              type="password"
              className="form-control"
              id="controlInput3"
              placeholder="password"
              aria-label="default input example"
              name="password"
              required
            />
          </div>
          <button type="submit" className="btn btn-primary">
            Зарегистрируйте меня
          </button>
        </form>
        <h5 className="msg" style={{ visibility: "hidden", color: "red" }} />
      </div>
    </Layout>
  );
}

module.exports = Registration;
' > ./src/views/Registration.jsx

# Login.jsx
echo 'const React = require("react");
const Layout = require("./Layout");

function Login(props) {
  return (
    <Layout {...props}>
      <script defer src="/js/login.js" />
      <div>
        <form name="logForm">
          <h3>Введите свои учетные данные для входа...</h3>
          <div className="mb-3">
            <label className="form-label" htmlFor="controlInput1">
              Укажите адрес электронной почты...
            </label>
            <input
              type="email"
              className="form-control"
              id="controlInput1"
              placeholder="name@example.com"
              aria-label="default input example"
              name="email"
              required
            />
          </div>
          <div className="mb-3">
            <label className="form-label" htmlFor="controlInput2">
              и обязательно введите пароль...
            </label>
            <input
              type="password"
              className="form-control"
              id="controlInput2"
              placeholder="password"
              aria-label="default input example"
              name="password"
              required
            />
          </div>
          <button type="submit" className="btn btn-primary">
            Войти
          </button>
        </form>
        <h5
          className="msg"
          style={{ visibility: "hidden", color: "red" }}
        />
      </div>
    </Layout>
  );
}

module.exports = Login;
' > ./src/views/Login.jsx

# Profile.jsx
echo 'const React = require("react");
const Layout = require("./Layout");

function Profile(props) {
  const { user } = props;
  return (
    <Layout {...props}>
      <script defer src="/js/editprofile.js" />
      <div>
        <div className="card">
          <h5 className="card-header">Учетные данные пользователя...</h5>
          <div className="card-body">
            <h5 className="card-title">{`Имя пользователя: ${user.name}`}</h5>
            <p className="card-text">{`Адрес электронной почты: ${user.email}`}</p>
            <button
              type="button"
              className="btn btn-outline-primary"
              data-bs-toggle="modal"
              data-bs-target="#profileModal"
            >
              Изменить
            </button>
            <div
              className="modal fade"
              id="profileModal"
              tabIndex="-1"
              aria-labelledby="ModalLabel"
              aria-hidden="true"
            >
              <div className="modal-dialog modal-dialog-centered">
                <div className="modal-content">
                  <div className="modal-header">
                    <h1 className="modal-title fs-5" id="ModalLabel">
                      Внесите изменения в учетные данные
                    </h1>
                    <button
                      type="button"
                      className="btn-close"
                      data-bs-dismiss="modal"
                      aria-label="Close"
                    />
                  </div>
                  <div className="modal-body">
                    <form name="EditUser">
                      <div className="mb-3">
                        <label
                          htmlFor="profile-name"
                          className="col-form-label"
                        >
                          Имя пользователя:
                        </label>
                        <input
                          type="text"
                          name="name"
                          className="form-control"
                          defaultValue={user.name}
                          id="profile-name"
                          required
                        />
                      </div>
                      <div className="mb-3">
                        <label
                          htmlFor="profile-email"
                          className="col-form-label"
                        >
                          Aдрес электронной почты:
                        </label>
                        <input
                          type="email"
                          className="form-control"
                          name="email"
                          id="profile-email"
                          defaultValue={user.email}
                          required
                        />
                      </div>
                      <button type="submit" className="btn btn-primary">
                        Сохранить
                      </button>
                    </form>
                  </div>
                  <div className="modal-footer">
                    <button
                      type="button"
                      className="btn btn-secondary"
                      data-bs-dismiss="modal"
                    >
                      Выйти
                    </button>
                  </div>
                </div>
              </div>
            </div>
            <a
              href={`/users/killer/${user.id}`}
              className="btn btn-outline-danger"
            >
              Удалить
            </a>
          </div>
        </div>
      </div>
    </Layout>
  );
}

module.exports = Profile;
' > ./src/views/Profile.jsx

# ---------------------------------------

# создаем middleware функцию проверки подключения checkConnect.js
echo "const { Sequelize } = require('sequelize');
const sequelize = new Sequelize(process.env.DB_URL);

async function checkConnect(req, res, next){
  try {
    await sequelize.authenticate();
    res.locals.dbConnect = 'БАЗА ДАННЫХ ПОДКЛЮЧЕНА';
    console.log('База данных успешно подключена 👍');
    next();
  } catch (error) {
    console.error('База не подключена 😢', error.message);
    console.log('БАЗА НЕ ПОДКЛЮЧЕНАЯ ==>', error);
    res.send(error);
  }
}
module.exports = checkConnect;
" > ./src/middlewares/checkConnect.js  

# создание файла renderComponent.js - используется middelware sss для отрисовки страниц *.jsx
echo "require('@babel/register');
const ReactDOMServer = require('react-dom/server');
const React = require('react');

const renderComponent = (reactComponent, props = {}, res) => {
  const reactElement = React.createElement(reactComponent, {
    ...props,
    ...res.locals,
    ...res.app.locals,
  });
  const html = ReactDOMServer.renderToStaticMarkup(reactElement);

  res.send(\`<!DOCTYPE html>\${html}\`);
};

module.exports = renderComponent;
" > ./src/lib/renderComponent.js

# создание файла ssr.js - middleware орисовки страниц
echo "const renderComponent = require('../lib/renderComponent');

function ssr(req, res, next) {
  res.render = (reactComponent, props) => {
    // renderComponent(reactComponent, { ...props }, res); // * без COOKIE и SESSION
    renderComponent(reactComponent, { ...props, user: req.session?.user }, res); // * когда созданы COOKIE и SESSION
  };
  next();
}

module.exports = ssr;
" > ./src/middlewares/ssr.js

# создание файла isAuth.js - middleware для проверки данных user-а и session 
echo "function isAuth(req, res, next) {
  const user = req.session?.user?.id;
  if (user) {
    next();
  } else {
    res.redirect('/');
  }
}

module.exports = isAuth;
" > ./src/middlewares/isAuth.js

# создаем router app.routes.js
echo "const router = require('express').Router();

const Home = require('../views/Home');

router.get('/', (req, res) => {
  res.render(Home, { title: 'Домашняя страница приложения...' });
});

module.exports = router;
" > ./src/routes/app.routes.js


# создадим router для авторизации и работы с ручками юзера
echo "const router = require('express').Router();
const bcrypt = require('bcrypt');
const { faker } = require('@faker-js/faker');
const isAuth = require('../middlewares/isAuth');
const { User } = require('../../db/models');
const Login = require('../views/Login');
const Registration = require('../views/Registration');
const Profile = require('../views/Profile');

// ручка перехода к форме авторизации
router.get('/login', (req, res) => {
  res.render(Login, {});
});

// ручка перехода к форме регистрации
router.get('/newuser', (req, res) => {
  res.render(Registration, {});
});

// ручка перехода к профилю пользователя
router.get('/profile', isAuth, async (req, res) => {
  const userId = req.session.user.id;
  const user = await User.findOne({ where: { id: userId } });
  res.render(Profile, { user });
});

// ручка редактирования профиля пользователя
router.post('/profile', isAuth, async (req, res) => {
  const { name, email } = req.body;
  try {
    const userUpdate = await User.update(
      {
        name,
        email,
      },
      {
        where: { id: req.session.user.id },
      }
    );
    if (userUpdate) {
      const user = await User.findOne({ where: { email } });
      req.session.user = user;
      res.json(user);
    }
  } catch (error) {
    console.log(error);
    res.send(error);
  }
});

// ручка добавления нового пользователя
router.post('/newuser', async (req, res) => {
  try {
    const { name, email, password } = req.body;
    const user = await User.findOne({ where: { email } });
    if (user) {
      res.json({ msg: 'Пользователь с такой почтой уже существует' });
    } else {
      const hashPass = await bcrypt.hash(password, 10);
      const newUser = await User.create({
        name,
        email,
        password: hashPass,
      });
      req.session.user = newUser;
      res.json(newUser);
    }
  } catch (error) {
    console.log(error);
    res.send(error);
  }
});

// авторизация пользователя
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ where: { email } });
    if (user) {
      const passCheck = await bcrypt.compare(password, user.password);
      if (passCheck) {
        req.session.user = user;
        res.json({ msg: 'Успешно вошли в систему!', userName: user.name });
      } else {
        res.json({ msg: 'Неверный пароль!' });
      }
    } else {
      res.json({
        msg: 'Пользователь с такими данными не найден, зарегистрируйтесь !',
      });
    }
  } catch (error) {
    console.log(error);
    res.send(error);
  }
});

// ручка выхода пользователя из системы
router.get('/logout', isAuth, (req, res) => {
  req.session.destroy((e) => {
    if (e) {
      console.log(e);
      return;
    }
    res.clearCookie('myProjectCookie');
    res.redirect('/');
  });
});

// * Ручка удаления Usera
router.get('/killer/:id', isAuth, async (req, res) => {
  try {
    const { id } = req.params;
    await User.destroy({ where: { id } });
    res.redirect('/users/logout');
  } catch (error) {
    console.log(error);
    res.send(error);
  }
});

module.exports = router;
" > ./src/routes/user.routes.js

# создаем файл .babelrc
echo '{
    "presets": [
      [
        "@babel/preset-env",
        {
          "targets": "> 5%",
          "modules": false
        }
      ],
      "@babel/preset-react"
    ]
 }
' > .babelrc

# создадим файл style.css
echo "body {
  background: linear-gradient(-45deg, #ee7752, #e73c7e, #23a6d5, #23d5ab);
  background-size: 400% 400%;
  animation: gradient 15s ease infinite;
  height: 100vh;
}

@keyframes gradient {
  0% {
    background-position: 0% 50%;
  }
  50% {
    background-position: 100% 50%;
  }
  100% {
    background-position: 0% 50%;
  }
}

.container {
  padding-right: 15px;
  padding-left: 15px;
  margin-right: auto;
  margin-left: auto;
}

.mainDiv {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-evenly;
}

form {
  max-width: auto;
  padding: 10px;
  margin: 10px;
  border-radius: 10px;
}
.msg {
  display: flex;
  justify-content: center;
}

.card {
  margin-top: 50px;
}
.btn {
  margin-right: 5px;
}

@media (min-width: 768px) {
  .container {
    max-width: 750px;
  }
}
@media (min-width: 992px) {
  .container {
    width: 970px;
  }
}
@media (min-width: 1200px) {
  .container {
    width: 1170px;
  }
}
" > public/css/style.css

# создадим файл application.js
echo "console.log('======= application.js =======');
" > public/js/application.js

# сoздадим файл login.js
echo "console.log('========== login.js ===========');

const { logForm } = document.forms;

logForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const data = new FormData(logForm);
  const msg = document.querySelector('.msg');

  try {
    const response = await fetch('/users/login', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(Object.fromEntries(data)),
    });
    const result = await response.json();

    if (result.userName) {
      msg.style.visibility = 'visible';
      msg.style.color = 'green';
      msg.innerText = \`\${result.msg}\`;

      const headerUser = \`
      <div class=\"userLogout\">
            <a href=\"/users/profile\" class=\"btn btn-primary\">
             Приветствую тебя, \${result.userName}!
            </a>
            <a class=\"btn btn-primary\" href='/users/logout'>Выход</a>
      </div>\`;
      document.querySelector('.logReg').remove();

      const navbar = document.getElementById('navbarSupportedContent');
      navbar.insertAdjacentHTML('beforeend', headerUser);
      setTimeout(() => {
        // msg.style.visibility = 'hidden';
        // logForm.remove();
        window.location.href = '/';
      }, 1000);
    } else {
      msg.style.visibility = 'visible';
      msg.innerText = \`\${result.msg}\`;
      document.querySelectorAll('input').forEach((el) => (el.value = ''));
      setTimeout(() => {
        msg.style.visibility = 'hidden';
      }, 2000);
      if (
        msg.innerText ===
        'Пользователь с такими данными не найден, зарегистрируйтесь !'
      ) {
        setTimeout(() => {
          msg.style.visibility = 'hidden';
          window.location.href = '/users/newuser';
        }, 2000);
      }
    }
  } catch (error) {
    msg.style.visibility = 'visible';
    msg.innerText = \`ОШИБКА!!!\n\${error}\`;
    document.querySelectorAll('input').forEach((el) => (el.value = ''));
    setTimeout(() => {
      msg.style.visibility = 'hidden';
    }, 2000);
  }
});
" > public/js/login.js

# создадим файл newuser.js
echo "console.log('========== newuser.js ===========');
const { regForm } = document.forms;

regForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const data = new FormData(regForm);
  try {
    const response = await fetch('/users/newuser', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(Object.fromEntries(data)),
    });
    console.log('response:', response);
    const result = await response.json();
    console.log('result:', result);
    const msg = document.querySelector('.msg');
    if (result.msg) {
      msg.style.visibility = 'visible';
      msg.innerText = \`\${result.msg}\`;
      document.querySelectorAll('input').forEach((el) => (el.value = ''));
    } else {
      msg.style.visibility = 'hidden';
      msg.innerText = '';
      const headerUser = \`
      <div class=\"userLogout\">
            <a href=\"/users/profile/\" class=\"btn btn-primary\">
             Приветствую тебя, \${result.name}!
            </a>
            <a class=\"btn btn-primary\" href='/users/logout'>Выход</a>
      </div>\`;
      document.querySelector('.logReg').remove();

      const navbar = document.getElementById('navbarSupportedContent');
      navbar.insertAdjacentHTML('beforeend', headerUser);
      setTimeout(() => {
        // msg.style.visibility = 'hidden';
        // regForm.remove();
        window.location.href = '/';
      }, 1000);
    }
  } catch (error) {
    msg.style.visibility = 'visible';
    msg.innerText = \`ОШИБКА!!!\n\${error}\`;
    document.querySelectorAll('input').forEach((el) => (el.value = ''));
    setTimeout(() => {
      msg.style.visibility = 'hidden';
    }, 2000);
  }
});
" > public/js/newuser.js

# создадим файл editprofile.js
echo "console.log('========== editprofile.js ===========');

const userModal = document.getElementById('profileModal');

if (userModal) {
  userModal.addEventListener('show.bs.modal', (event) => {
    const { EditUser } = document.forms;
    EditUser.addEventListener('submit', async (event) => {
      event.preventDefault();
      const data = new FormData(EditUser);
      try {
        const response = await fetch('/users/profile', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(Object.fromEntries(data)),
        });
        const result = await response.json();
        const headerUser = \`
        <div class=\"userLogout\">
              <a href=\"/users/profile\" class=\"btn btn-primary\">
               Приветствую тебя, \${result.name}!
              </a>
              <a class=\"btn btn-primary\" href='/users/logout'>Выход</a>
        </div>\`;

        const navbar = document.getElementById('navbarSupportedContent');
        navbar.insertAdjacentHTML('beforeend', headerUser);
        window.location.reload();
      } catch (error) {
        console.log(error);
      }
    });
  });
}
" > public/js/editprofile.js
 

# создаем базу ЮЗЕРОВ (поля name, email, password)
# ! если требуются дополнительные поля, добавь в конце строки с ...model:generat... 
exports DB_URL=postgres://postgres:postgres@localhost:5432/db_Name
npx sequelize-cli db:create
npx sequelize-cli model:generate --name User --attributes name:string,email:string,password:string
npx sequelize-cli db:migrate

# настроим eslint
npx eslint --init

# запустить проект-> npm run dev
# если занят порт и в терминале ошибка:
# ! Error: listen EADDRINUSE: address already in use :::3000
# использовать команду-> lsof -i :3000 , где 3000 номер порта
# затем-> sudo kill -9 <PID> , где <PID> - номер подключения полученный 
# в результате работы команды lsof
