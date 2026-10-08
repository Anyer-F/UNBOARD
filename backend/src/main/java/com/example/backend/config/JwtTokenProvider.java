package com.example.backend.config;

import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Function;

import javax.crypto.spec.SecretKeySpec;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

@Component
public class JwtTokenProvider {

    @Value("${app.jwt.secret:unbound-super-secret-key-2026-huehuetenango-management-system-secret-key}")
    private String jwtSecret;

    @Value("${app.jwt.expiration-ms:86400000}") // 24 horas
    private long jwtExpirationMs;

    private Key getSigningKey() {
        byte[] keyBytes = this.jwtSecret.getBytes(StandardCharsets.UTF_8);
        return Keys.hmacShaKeyFor(keyBytes);
    }

    public String generarToken(String correo, String nombre, String rol, Long usuarioId, Long coordinadorId, Long apadrinadoId) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("id", usuarioId);
        claims.put("nombre", nombre);
        claims.put("rol", rol);
        claims.put("coordinadorId", coordinadorId);
        claims.put("apadrinadoId", apadrinadoId);

        Date ahora = new Date();
        Date fechaExpiracion = new Date(ahora.getTime() + jwtExpirationMs);

        return Jwts.builder()
                .claims(claims)
                .subject(correo)
                .issuedAt(ahora)
                .expiration(fechaExpiracion)
                .signWith(getSigningKey())
                .compact();
    }

    public String obtenerCorreoDelToken(String token) {
        return obtenerClaim(token, Claims::getSubject);
    }

    public <T> T obtenerClaim(String token, Function<Claims, T> claimsResolver) {
        final Claims claims = obtenerTodosLosClaims(token);
        return claimsResolver.apply(claims);
    }

    public Claims obtenerTodosLosClaims(String token) {
        return Jwts.parser()
                .verifyWith((javax.crypto.SecretKey) getSigningKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public boolean validarToken(String token, UserDetails userDetails) {
        final String correo = obtenerCorreoDelToken(token);
        return (correo.equals(userDetails.getUsername()) && !estaExpirado(token));
    }

    public boolean validarToken(String token) {
        try {
            Jwts.parser()
                    .verifyWith((javax.crypto.SecretKey) getSigningKey())
                    .build()
                    .parseSignedClaims(token);
            return !estaExpirado(token);
        } catch (Exception e) {
            return false;
        }
    }

    private boolean estaExpirado(String token) {
        final Date expiracion = obtenerClaim(token, Claims::getExpiration);
        return expiracion.before(new Date());
    }
}
