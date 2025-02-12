import { Pool } from "pg";


const pool =  new Pool({
    user:'postgres',
    password: 'Fahad=623',
    host:'localhost',
    port : 5432,
    database: 'fahaddb'
})


export default pool;