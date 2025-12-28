# vue-frontend-edge-proxy-forward-proxy-reverse-proxy  

```
.
├── build-docker.sh
├── md-values-back-end
│   ├── back-end
│   │   ├── dist
│   │   ├── eslint.config.mjs
│   │   ├── nest-cli.json
│   │   ├── node_modules
│   │   ├── package-lock.json
│   │   ├── package.json
│   │   ├── README.md
│   │   ├── src
│   │   ├── test
│   │   ├── tsconfig.build.json
│   │   └── tsconfig.json
│   ├── docker
│   │   ├── docker-compose.yml
│   │   ├── Dockerfile
│   │   └── start-backend.sh
│   └── reverse-proxy           // proxy, in front of the middleware server 
│       ├── logs
│       ├── nginx-docker.conf
│       └── nginx.conf
├── md-values-front-end
│   ├── docker
│   │   ├── docker-compose.yml
│   │   ├── Dockerfile
│   │   └── start-frontend.sh
│   ├── edge-proxy              // proxy, definable browser url (not localhost:4200)
│   │   ├── logs
│   │   ├── nginx-mdvalues.conf
│   │   └── ssl
│   ├── forward-proxy           // proxy, where the Front-End sends api calls 
│   │   ├── logs
│   │   ├── nginx-docker.conf
│   │   └── nginx.conf
│   └── front-end
│       ├── angular.json        // mod 
│       ├── node_modules
│       ├── package-lock.json
│       ├── package.json
│       ├── proxy.conf.json     // mod 
│       ├── README.md
│       ├── src
│       ├── tsconfig.app.json
│       ├── tsconfig.json
│       └── tsconfig.spec.json
├── README.md
├── run.sh
└── start-docker.sh
```
