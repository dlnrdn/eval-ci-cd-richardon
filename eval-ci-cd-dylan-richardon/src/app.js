const express = require('express')
const routes = require('./routes')

const app = express()

app.use('/', routes)

// Démarre le serveur uniquement si le fichier est exécuté directement
if (require.main === module) {
    const port = process.env.PORT || 3000
    app.listen(port, () => {
        console.log(`Server running on port ${port}`)
    })
}

module.exports = app