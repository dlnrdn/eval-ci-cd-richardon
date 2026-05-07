// Permet de tester l'API avec supertest
const request = require('supertest')
// Permet de charger l'application principale
const app = require('../src/app')

// Définit le test pour l'API Endpoints
describe('API Endpoints', () => {
    // Test pour vérifier si l'API retourne le status ok
    it('GET /health should return status ok', async () => {
        // Test la route /health avec supertest
        const res = await request(app).get('/health')
        // Vérifie que le status code est 200
        expect(res.statusCode).toEqual(200)
        // Vérifie que le body est { status: 'ok' }
        expect(res.body).toEqual({ status: 'ok' })
    })

    it('GET /time should return a valid time', async () => {
        // Test la route /time avec supertest
        const res = await request(app).get('/time')
        // Vérifie que le status code est 200
        expect(res.statusCode).toEqual(200)
        // Vérifie que le body a une propriété time
        expect(res.body).toHaveProperty('time')
        // Vérifie que le format de la date est valide
        expect(new Date(res.body.time).toISOString()).toBe(res.body.time)
    })
})