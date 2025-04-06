import { Pool } from "pg";
import { config } from "dotenv";
config();


const pool =  new Pool({
    user:'postgres',
    password: 'Fahad=623',
    host: process.env.DB_HOST,
    port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : undefined, // Convert to number
    database: 'fahaddb'
})


export default pool;